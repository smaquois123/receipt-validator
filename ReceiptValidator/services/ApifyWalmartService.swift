//
//  ApifyWalmartService.swift
//  ReceiptValidator
//
//  Created by JC Smith on 1/3/26.
//

import Foundation

/// Service for scraping Walmart product data using Apify
/// Solves the UPC search problem - can search Walmart by UPC code directly
class ApifyWalmartService {
    
    private let apiToken: String
    private let actorId: String // Walmart scraper actor ID
    private let baseURL = "https://api.apify.com/v2"
    
    init(
        apiToken: String = AppConfiguration.ApifyAPIToken,
        actorId: String = "junglee/walmart-scraper" // Popular Walmart scraper
    ) {
        self.apiToken = apiToken
        self.actorId = actorId
    }
    
    // MARK: - Public Methods
    
    /// Search Walmart by UPC code (the solution to your problem!)
    func searchByUPC(_ upc: String) async throws -> ApifyWalmartProduct? {
        let searchURL = "https://www.walmart.com/search?q=\(upc)"
        return try await scrapeProduct(url: searchURL, expectFirstResult: true)
    }
    
    /// Search Walmart by product name (fallback for items without UPC)
    func searchByName(_ productName: String) async throws -> ApifyWalmartProduct? {
        let encodedName = productName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? productName
        let searchURL = "https://www.walmart.com/search?q=\(encodedName)"
        return try await scrapeProduct(url: searchURL, expectFirstResult: true)
    }
    
    /// Scrape a specific Walmart product page directly
    func scrapeProductPage(url: String) async throws -> ApifyWalmartProduct? {
        return try await scrapeProduct(url: url, expectFirstResult: false)
    }
    
    /// Validate receipt item against Walmart website
    func validateReceiptItem(_ item: ReceiptItem) async throws -> ApifyValidationResult {
        print("🔍 Validating: \(item.name)")
        print("   Receipt Price: $\(String(format: "%.2f", item.price))")
        
        // Try UPC search first (most accurate)
        var product: ApifyWalmartProduct?
        
        if let upc = item.upc, !upc.isEmpty {
            print("   Searching by UPC: \(upc)")
            product = try await searchByUPC(upc)
            
            if let foundProduct = product {
                print("   ✅ Found by UPC: \(foundProduct.name)")
                print("   Website Price: $\(String(format: "%.2f", foundProduct.price))")
                
                // Verify UPC match
                if let foundUPC = foundProduct.upc, foundUPC != upc {
                    print("   ⚠️ UPC mismatch! Expected: \(upc), Found: \(foundUPC)")
                }
            }
        }
        
        // Fallback to name search if UPC search failed
        if product == nil {
            print("   Searching by name: \(item.name)")
            product = try await searchByName(item.name)
            
            if let foundProduct = product {
                print("   ⚠️ Found by name (lower confidence): \(foundProduct.name)")
                print("   Website Price: $\(String(format: "%.2f", foundProduct.price))")
            }
        }
        
        guard let product = product else {
            return ApifyValidationResult(
                item: item,
                websitePrice: nil,
                priceDifference: nil,
                percentDifference: nil,
                status: .notFound,
                confidence: .none,
                notes: "Product not found on Walmart.com"
            )
        }
        
        // Calculate difference
        let difference = item.price - product.price
        let percentDiff = (difference / product.price) * 100
        
        print("   Difference: $\(String(format: "%.2f", difference)) (\(String(format: "%.1f", percentDiff))%)")
        
        // Determine status
        let status = determineStatus(
            difference: difference,
            percentDiff: percentDiff,
            hasUPC: item.upc != nil
        )
        
        let confidence = determineConfidence(
            upcMatched: item.upc == product.upc,
            hasUPC: item.upc != nil
        )
        
        return ApifyValidationResult(
            item: item,
            websitePrice: product.price,
            priceDifference: difference,
            percentDifference: percentDiff,
            status: status,
            confidence: confidence,
            notes: generateNotes(status: status, difference: difference, percentDiff: percentDiff)
        )
    }
    
    // MARK: - Private Methods
    
    private func scrapeProduct(url: String, expectFirstResult: Bool) async throws -> ApifyWalmartProduct? {
        // Step 1: Start the scraper actor
        let runId = try await startScraper(url: url)
        
        // Step 2: Wait for completion (with timeout)
        let results = try await waitForResults(runId: runId, timeout: 60)
        
        // Step 3: Parse and return first product
        return expectFirstResult ? results.first : results.first
    }
    
    private func startScraper(url: String) async throws -> String {
        let endpoint = "\(baseURL)/acts/\(actorId)/runs?token=\(apiToken)"
        
        guard let requestURL = URL(string: endpoint) else {
            throw ApifyError.invalidURL
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let input = ApifyInput(
            startUrls: [ApifyURL(url: url)],
            maxItems: 1,
            proxyConfiguration: ApifyProxy(useApifyProxy: true)
        )
        
        request.httpBody = try JSONEncoder().encode(input)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw ApifyError.scraperStartFailed
        }
        
        let runResponse = try JSONDecoder().decode(ApifyRunResponse.self, from: data)
        return runResponse.data.id
    }
    
    private func waitForResults(runId: String, timeout: TimeInterval) async throws -> [ApifyWalmartProduct] {
        let endpoint = "\(baseURL)/actor-runs/\(runId)?token=\(apiToken)"
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            guard let url = URL(string: endpoint) else {
                throw ApifyError.invalidURL
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            let status = try JSONDecoder().decode(ApifyRunStatusResponse.self, from: data)
            
            switch status.data.status {
            case "SUCCEEDED":
                // Get results from dataset
                return try await fetchResults(datasetId: status.data.defaultDatasetId)
                
            case "FAILED", "ABORTED", "TIMED-OUT":
                throw ApifyError.scraperFailed(status.data.status)
                
            case "RUNNING", "READY":
                // Wait and retry
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                continue
                
            default:
                throw ApifyError.unknownStatus(status.data.status)
            }
        }
        
        throw ApifyError.timeout
    }
    
    private func fetchResults(datasetId: String) async throws -> [ApifyWalmartProduct] {
        let endpoint = "\(baseURL)/datasets/\(datasetId)/items?token=\(apiToken)"
        
        guard let url = URL(string: endpoint) else {
            throw ApifyError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        // Apify returns an array of items
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        return try decoder.decode([ApifyWalmartProduct].self, from: data)
    }
    
    private func determineStatus(difference: Double, percentDiff: Double, hasUPC: Bool) -> ApifyValidationStatus {
        let tolerance = AppConfiguration.priceTolerancePercentage * 100
        
        if abs(percentDiff) <= 1.0 {
            return .exactMatch
        } else if abs(percentDiff) <= tolerance {
            return .withinTolerance
        } else if difference > tolerance && difference <= tolerance * 2 {
            return .possibleOvercharge
        } else if difference > tolerance * 2 {
            return .significantOvercharge
        } else {
            return .receiptLower
        }
    }
    
    private func determineConfidence(upcMatched: Bool, hasUPC: Bool) -> ApifyConfidenceLevel {
        if upcMatched && hasUPC {
            return .high
        } else if hasUPC {
            return .medium
        } else {
            return .low
        }
    }
    
    private func generateNotes(status: ApifyValidationStatus, difference: Double, percentDiff: Double) -> String {
        switch status {
        case .exactMatch:
            return "✅ Price matches Walmart.com"
        case .withinTolerance:
            return "✓ Within normal in-store vs online variance"
        case .receiptLower:
            return "✓ You paid less than Walmart.com price"
        case .possibleOvercharge:
            return "⚠️ Receipt price is \(String(format: "%.1f%%", percentDiff)) higher - possible overcharge"
        case .significantOvercharge:
            return "🚨 Receipt price is $\(String(format: "%.2f", difference)) higher - likely billing error"
        case .notFound:
            return "Product not found on Walmart.com"
        }
    }
}

// MARK: - Models

struct ApifyWalmartProduct: Codable {
    let name: String
    let price: Double
    let upc: String?
    let itemId: String?
    let url: String?
    let inStock: Bool?
    
    enum CodingKeys: String, CodingKey {
        case name = "productName"
        case price = "currentPrice"
        case upc
        case itemId
        case url = "productUrl"
        case inStock = "availableOnline"
    }
}

struct ApifyValidationResult {
    let item: ReceiptItem
    let websitePrice: Double?
    let priceDifference: Double?
    let percentDifference: Double?
    let status: ApifyValidationStatus
    let confidence: ApifyConfidenceLevel
    let notes: String
}

enum ApifyValidationStatus {
    case exactMatch
    case withinTolerance
    case receiptLower
    case possibleOvercharge
    case significantOvercharge
    case notFound
}

enum ApifyConfidenceLevel {
    case high    // UPC matched
    case medium  // Name matched, has UPC but didn't match
    case low     // Name matched, no UPC available
    case none    // Not found
}

// Apify API Models
struct ApifyInput: Codable {
    let startUrls: [ApifyURL]
    let maxItems: Int
    let proxyConfiguration: ApifyProxy
}

struct ApifyURL: Codable {
    let url: String
}

struct ApifyProxy: Codable {
    let useApifyProxy: Bool
}

struct ApifyRunResponse: Codable {
    let data: ApifyRunData
}

struct ApifyRunData: Codable {
    let id: String
}

struct ApifyRunStatusResponse: Codable {
    let data: ApifyRunStatus
}

struct ApifyRunStatus: Codable {
    let id: String
    let status: String
    let defaultDatasetId: String
}

enum ApifyError: LocalizedError {
    case invalidURL
    case scraperStartFailed
    case scraperFailed(String)
    case unknownStatus(String)
    case timeout
    case noResults
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .scraperStartFailed:
            return "Failed to start Apify scraper"
        case .scraperFailed(let status):
            return "Scraper failed with status: \(status)"
        case .unknownStatus(let status):
            return "Unknown scraper status: \(status)"
        case .timeout:
            return "Scraper timed out"
        case .noResults:
            return "No results returned from scraper"
        }
    }
}

// MARK: - Usage Example
/*
 let service = ApifyWalmartService()
 
 // Search by UPC (solves the "Seagrams" problem!)
 let product = try await service.searchByUPC("012000161292")
 print("Found: \(product.name) - $\(product.price)")
 
 // Validate receipt item
 let result = try await service.validateReceiptItem(receiptItem)
 if result.status == .possibleOvercharge {
     print("⚠️ \(result.notes)")
     print("Website: $\(result.websitePrice!)")
     print("Receipt: $\(result.item.price)")
 }
 */
