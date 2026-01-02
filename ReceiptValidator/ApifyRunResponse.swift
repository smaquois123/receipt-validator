//
//  ApifyRunResponse.swift
//  ReceiptValidator
//
//  Created by JC Smith on 12/31/25.
//


import Foundation

// MARK: - Models

struct ApifyRunResponse: Codable {
    let data: RunData
}

struct RunData: Codable {
    let id: String
    let status: String
    let defaultDatasetId: String
}

struct ApifyWalmartProduct: Codable {
    let item: ApifyProductItem
    let sku: [ProductSKU]?
    let description: ProductDescription?
    let reviews: ProductReviews?
}

struct ApifyProductItem: Codable {
    let itemId: String
    let productId: String
    let upc: String?
    let title: String
    let currentPrice: String?
    let wasPrice: String?
    let availabilityStatus: String?
    let brand: String?
}

struct ProductSKU: Codable {
    let id: String
    let usItemId: String
    let currentPrice: String?
    let wasPrice: String?
    let availabilityStatus: String?
}

struct ProductDescription: Codable {
    let allImages: [String]?
}

struct ProductReviews: Codable {
    let averageRating: Double?
    let totalReviewCount: Int?
}

// MARK: - Walmart Product Validator

class WalmartProductValidator {
    
    private let apifyToken: String
    private let actorId = "web_wanderer/walmart-product-scraper"
    
    init(apifyToken: String) {
        self.apifyToken = apifyToken
    }
    
    /// Validates a product price against Walmart by searching for the product name and matching the UPC
    /// - Parameters:
    ///   - productName: The product name to search for (e.g., "itch cream")
    ///   - upc: The UPC code to match (e.g., "036373644700")
    ///   - expectedPrice: The price from the receipt (e.g., 4.97)
    ///   - region: Walmart region ("US" or "CA")
    /// - Returns: ValidationResult with matching product and price comparison
    func validateProduct(
        productName: String,
        upc: String,
        expectedPrice: Double,
        region: String = "US"
    ) async throws -> ValidationResult {
        
        // Step 1: Run the search
        let products = try await searchProducts(productName: productName, region: region)
        
        // Step 2: Filter by UPC
        guard let matchingProduct = products.first(where: { product in
            product.item.upc == upc
        }) else {
            return ValidationResult(
                found: false,
                product: nil,
                priceMatch: false,
                priceDifference: nil,
                message: "No product found with UPC: \(upc)"
            )
        }
        
        // Step 3: Compare prices
        guard let priceString = matchingProduct.item.currentPrice,
              let actualPrice = extractPrice(from: priceString) else {
            return ValidationResult(
                found: true,
                product: matchingProduct,
                priceMatch: false,
                priceDifference: nil,
                message: "Product found but price unavailable"
            )
        }
        
        let priceDifference = abs(actualPrice - expectedPrice)
        let priceMatch = priceDifference < 0.01 // Allow for floating point precision
        
        return ValidationResult(
            found: true,
            product: matchingProduct,
            priceMatch: priceMatch,
            priceDifference: priceDifference,
            message: priceMatch 
                ? "Price matches! (\(priceString))"
                : "Price mismatch: Expected $\(String(format: "%.2f", expectedPrice)), Found \(priceString)"
        )
    }
    
    /// Searches for products on Walmart using the Apify Actor
    /// - Parameters:
    ///   - productName: The search query
    ///   - region: Walmart region ("US" or "CA")
    ///   - maxPages: Maximum number of search result pages to scrape (1-10)
    /// - Returns: Array of ApifyWalmartProduct objects
    func searchProducts(
        productName: String,
        region: String = "US",
        maxPages: Int = 1
    ) async throws -> [ApifyWalmartProduct] {
        
        // Step 1: Start the Actor run
        let runId = try await startActorRun(searchQuery: productName, region: region, maxPages: maxPages)
        
        // Step 2: Wait for completion
        try await waitForCompletion(runId: runId)
        
        // Step 3: Fetch results
        let products = try await fetchResults(runId: runId)
        
        return products
    }
    
    // MARK: - Private Methods
    
    private func startActorRun(searchQuery: String, region: String, maxPages: Int) async throws -> String {
        let url = URL(string: "https://api.apify.com/v2/acts/\(actorId)/runs?token=\(apifyToken)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let input: [String: Any] = [
            "search": [searchQuery],
            "reg": region,
            "lang": "en",
            "depth": maxPages
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: input)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WalmartValidatorError.apiError("Failed to start Actor run")
        }
        
        let runResponse = try JSONDecoder().decode(ApifyRunResponse.self, from: data)
        return runResponse.data.id
    }
    
    private func waitForCompletion(runId: String, maxAttempts: Int = 60) async throws {
        let url = URL(string: "https://api.apify.com/v2/actor-runs/\(runId)?token=\(apifyToken)")!
        
        for attempt in 0..<maxAttempts {
            let (data, _) = try await URLSession.shared.data(from: url)
            let runResponse = try JSONDecoder().decode(ApifyRunResponse.self, from: data)
            
            switch runResponse.data.status {
            case "SUCCEEDED":
                return
            case "FAILED", "ABORTED", "TIMED-OUT":
                throw WalmartValidatorError.runFailed(runResponse.data.status)
            default:
                // Still running, wait 2 seconds before checking again
                try await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
        
        throw WalmartValidatorError.timeout
    }
    
    private func fetchResults(runId: String) async throws -> [ApifyWalmartProduct] {
        // Get the run details to find the dataset ID
        let runUrl = URL(string: "https://api.apify.com/v2/actor-runs/\(runId)?token=\(apifyToken)")!
        let (runData, _) = try await URLSession.shared.data(from: runUrl)
        let runResponse = try JSONDecoder().decode(ApifyRunResponse.self, from: runData)
        
        // Fetch dataset items
        let datasetUrl = URL(string: "https://api.apify.com/v2/datasets/\(runResponse.data.defaultDatasetId)/items?token=\(apifyToken)")!
        let (data, response) = try await URLSession.shared.data(from: datasetUrl)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WalmartValidatorError.apiError("Failed to fetch results")
        }
        
        let products = try JSONDecoder().decode([ApifyWalmartProduct].self, from: data)
        return products
    }
    
    private func extractPrice(from priceString: String) -> Double? {
        // Remove currency symbols and extract numeric value
        let cleanString = priceString.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleanString)
    }
}

// MARK: - Result Models

struct ValidationResult {
    let found: Bool
    let product: ApifyWalmartProduct?
    let priceMatch: Bool
    let priceDifference: Double?
    let message: String
}

// MARK: - Errors

enum WalmartValidatorError: Error {
    case apiError(String)
    case runFailed(String)
    case timeout
    case invalidResponse
}

// MARK: - Usage Example

/*
// Example usage:
let validator = WalmartProductValidator(apifyToken: "YOUR_APIFY_TOKEN_HERE")

Task {
    do {
        let result = try await validator.validateProduct(
            productName: "itch cream",
            upc: "036373644700",
            expectedPrice: 4.97,
            region: "US"
        )
        
        print(result.message)
        
        if result.found {
            if let product = result.product {
                print("Product: \(product.item.title)")
                print("Brand: \(product.item.brand ?? "N/A")")
                print("Current Price: \(product.item.currentPrice ?? "N/A")")
                if let diff = result.priceDifference {
                    print("Price Difference: $\(String(format: "%.2f", diff))")
                }
            }
        }
        
    } catch {
        print("Error: \(error)")
    }
}
*/
