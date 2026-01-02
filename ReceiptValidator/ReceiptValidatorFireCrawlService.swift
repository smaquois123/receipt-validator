//
//  FireCrawlService.swift
//  ReceiptValidator
//
//  Created by JC Smith on 1/1/26.
//

import Foundation

/// Service for scraping product data using FireCrawl API
class FireCrawlService {
    
    // TODO: Replace with your actual FireCrawl API key
    // Sign up at: https://firecrawl.dev
    private let apiKey: String
    private let baseURL = "https://api.firecrawl.dev/v1"
    
    init(apiKey: String = "") {
        self.apiKey = apiKey
    }
    
    // MARK: - Public Methods
    
    /// Scrapes Walmart product data for a given search query or UPC
    /// - Parameters:
    ///   - searchQuery: Product name to search for (fallback if UPC not provided)
    ///   - upc: UPC barcode (preferred for accurate searching)
    func scrapeWalmartProduct(searchQuery: String, upc: String? = nil) async throws -> WalmartProductData? {
        // Prefer UPC search if available
        let searchURL: String
        if let upc = upc, !upc.isEmpty {
            // Search by UPC - much more accurate!
            searchURL = buildWalmartSearchURL(query: upc)
        } else {
            // Fallback to name search
            searchURL = buildWalmartSearchURL(query: searchQuery)
        }
        
        let searchResults = try await scrapeURL(searchURL)
        
        // Extract product URL from search results
        guard let productURL = extractProductURL(from: searchResults) else {
            return nil
        }
        
        // Scrape the actual product page
        let productData = try await scrapeURL(productURL)
        return parseWalmartProduct(from: productData)
    }
    
    /// Scrapes Target product data
    /// - Parameters:
    ///   - searchQuery: Product name to search for (fallback if UPC not provided)
    ///   - upc: UPC barcode (preferred for accurate searching)
    func scrapeTargetProduct(searchQuery: String, upc: String? = nil) async throws -> ProductData? {
        let searchURL: String
        if let upc = upc, !upc.isEmpty {
            searchURL = buildTargetSearchURL(query: upc)
        } else {
            searchURL = buildTargetSearchURL(query: searchQuery)
        }
        
        let results = try await scrapeURL(searchURL)
        
        guard let productURL = extractProductURL(from: results) else {
            return nil
        }
        
        let productData = try await scrapeURL(productURL)
        return parseTargetProduct(from: productData)
    }
    
    /// Scrapes Costco product data
    /// - Parameters:
    ///   - searchQuery: Product name to search for (fallback if itemNumber not provided)
    ///   - itemNumber: Costco item number (preferred for accurate searching)
    func scrapeCostcoProduct(searchQuery: String, itemNumber: String? = nil) async throws -> ProductData? {
        let searchURL: String
        if let itemNumber = itemNumber, !itemNumber.isEmpty {
            searchURL = buildCostcoSearchURL(query: itemNumber)
        } else {
            searchURL = buildCostcoSearchURL(query: searchQuery)
        }
        
        let results = try await scrapeURL(searchURL)
        
        guard let productURL = extractProductURL(from: results) else {
            return nil
        }
        
        let productData = try await scrapeURL(productURL)
        return parseCostcoProduct(from: productData)
    }
    
    // MARK: - FireCrawl API Methods
    
    /// Scrapes a URL using FireCrawl API
    private func scrapeURL(_ urlString: String) async throws -> FireCrawlResponse {
        guard !apiKey.isEmpty else {
            throw FireCrawlError.apiKeyMissing
        }
        
        // Trim whitespace from API key
        let cleanAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let url = URL(string: "\(baseURL)/scrape") else {
            throw FireCrawlError.invalidURL
        }
        print (cleanAPIKey)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(cleanAPIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = FireCrawlRequest(
            url: urlString,
            formats: ["markdown", "html"],
            onlyMainContent: true,
            waitFor: 2000 // Wait 2 seconds for JS to load
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FireCrawlError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            // Try to decode error message from response
            if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorData["error"] {
                throw FireCrawlError.apiError(message: errorMessage)
            }
            throw FireCrawlError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        return try decoder.decode(FireCrawlResponse.self, from: data)
    }
    
    // MARK: - URL Building
    
    private func buildWalmartSearchURL(query: String) -> String {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return "https://www.walmart.com/search?q=\(encodedQuery)"
    }
    
    private func buildTargetSearchURL(query: String) -> String {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return "https://www.target.com/s?searchTerm=\(encodedQuery)"
    }
    
    private func buildCostcoSearchURL(query: String) -> String {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return "https://www.costco.com/CatalogSearch?keyword=\(encodedQuery)"
    }
    
    // MARK: - Response Parsing
    
    private func extractProductURL(from response: FireCrawlResponse) -> String? {
        // Look for product URLs in the markdown or HTML content
        let content = response.data.markdown ?? response.data.html ?? ""
        
        // Walmart product URL pattern
        if let range = content.range(of: #"https://www\.walmart\.com/ip/[^"\s]+"#, options: .regularExpression) {
            return String(content[range])
        }
        
        // Target product URL pattern
        if let range = content.range(of: #"https://www\.target\.com/p/[^"\s]+"#, options: .regularExpression) {
            return String(content[range])
        }
        
        // Costco product URL pattern
        if let range = content.range(of: #"https://www\.costco\.com/[^"\s]+\.product\.\d+\.html"#, options: .regularExpression) {
            return String(content[range])
        }
        
        return nil
    }
    
    private func parseWalmartProduct(from response: FireCrawlResponse) -> WalmartProductData? {
        let content = response.data.markdown ?? response.data.html ?? ""
        
        // Extract price using regex patterns
        // Walmart typically shows prices like: "$12.99" or "Now $12.99"
        guard let price = extractPrice(from: content, patterns: [
            #"\$(\d+\.\d{2})"#,
            #"Now \$(\d+\.\d{2})"#,
            #"Price \$(\d+\.\d{2})"#
        ]) else {
            return nil
        }
        
        // Extract product name (usually in a heading)
        let name = extractProductName(from: content)
        
        // Extract UPC if available
        let upc = extractUPC(from: content)
        
        return WalmartProductData(
            name: name,
            price: price,
            upc: upc,
            url: response.data.metadata?.sourceURL,
            inStock: extractStockStatus(from: content)
        )
    }
    
    private func parseTargetProduct(from response: FireCrawlResponse) -> ProductData? {
        let content = response.data.markdown ?? response.data.html ?? ""
        
        guard let price = extractPrice(from: content, patterns: [
            #"\$(\d+\.\d{2})"#,
            #"price\"\s*:\s*\"(\d+\.\d{2})"#
        ]) else {
            return nil
        }
        
        let name = extractProductName(from: content)
        
        return ProductData(name: name, price: price, url: response.data.metadata?.sourceURL)
    }
    
    private func parseCostcoProduct(from response: FireCrawlResponse) -> ProductData? {
        let content = response.data.markdown ?? response.data.html ?? ""
        
        guard let price = extractPrice(from: content, patterns: [
            #"\$(\d+\.\d{2})"#,
            #"Price \$(\d+\.\d{2})"#
        ]) else {
            return nil
        }
        
        let name = extractProductName(from: content)
        
        return ProductData(name: name, price: price, url: response.data.metadata?.sourceURL)
    }
    
    // MARK: - Helper Methods
    
    private func extractPrice(from content: String, patterns: [String]) -> Double? {
        for pattern in patterns {
            if let range = content.range(of: pattern, options: .regularExpression),
               let match = try? NSRegularExpression(pattern: pattern).firstMatch(
                in: content,
                range: NSRange(range, in: content)
               ) {
                let matchRange = Range(match.range(at: 1), in: content)
                if let matchRange = matchRange,
                   let price = Double(content[matchRange]) {
                    return price
                }
            }
        }
        return nil
    }
    
    private func extractProductName(from content: String) -> String {
        // Look for common product name patterns in markdown
        let lines = content.components(separatedBy: .newlines)
        
        // Usually the first significant heading is the product name
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") && !trimmed.hasPrefix("####") {
                return trimmed.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        
        return "Unknown Product"
    }
    
    private func extractUPC(from content: String) -> String? {
        // Look for UPC patterns (typically 12 digits)
        let pattern = #"UPC[:\s]+(\d{12})"#
        if let range = content.range(of: pattern, options: [.regularExpression, .caseInsensitive]),
           let match = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive).firstMatch(
            in: content,
            range: NSRange(range, in: content)
           ) {
            let matchRange = Range(match.range(at: 1), in: content)
            if let matchRange = matchRange {
                return String(content[matchRange])
            }
        }
        return nil
    }
    
    private func extractStockStatus(from content: String) -> Bool {
        let inStockPatterns = ["in stock", "add to cart", "buy now"]
        let outOfStockPatterns = ["out of stock", "sold out", "unavailable"]
        
        let lowercaseContent = content.lowercased()
        
        // Check for out of stock first (more specific)
        for pattern in outOfStockPatterns {
            if lowercaseContent.contains(pattern) {
                return false
            }
        }
        
        // Check for in stock
        for pattern in inStockPatterns {
            if lowercaseContent.contains(pattern) {
                return true
            }
        }
        
        // Default to true if unclear
        return true
    }
}

// MARK: - Models

struct FireCrawlRequest: Codable {
    let url: String
    let formats: [String]
    let onlyMainContent: Bool
    let waitFor: Int
}

struct FireCrawlResponse: Codable {
    let success: Bool
    let data: FireCrawlData
}

struct FireCrawlData: Codable {
    let markdown: String?
    let html: String?
    let metadata: FireCrawlMetadata?
}

struct FireCrawlMetadata: Codable {
    let title: String?
    let description: String?
    let sourceURL: String?
}

struct WalmartProductData {
    let name: String
    let price: Double
    let upc: String?
    let url: String?
    let inStock: Bool
}

struct ProductData {
    let name: String
    let price: Double
    let url: String?
}

enum FireCrawlError: LocalizedError {
    case apiKeyMissing
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case apiError(message: String)
    case productNotFound
    case parsingError
    
    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "FireCrawl API key is missing. Sign up at firecrawl.dev"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from FireCrawl API"
        case .httpError(let code):
            return "HTTP error: \(code). Please check your API key and ensure it's valid."
        case .apiError(let message):
            return "FireCrawl API error: \(message)"
        case .productNotFound:
            return "Product not found"
        case .parsingError:
            return "Failed to parse product data"
        }
    }
}
