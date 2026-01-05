//
//  WalmartAPIService.swift
//  ReceiptValidator
//
//  Created by JC Smith on 12/23/25.
//
//  EXAMPLE: Walmart API integration
//  Note: You'll need to sign up at https://developer.walmart.com
//

import Foundation

/// Example implementation for Walmart API price checking
/// This is a template - customize based on actual API documentation
class WalmartAPIService {
    
    // TODO: Replace with your actual API key from developer.walmart.com
    // Oxylabs api key 0Ff1ouPK=bDnK_Z
    //Username smaquois123
    
    //curl 'https://realtime.oxylabs.io/v1/queries' --user 'smaquois123:0Ff1ouPK=bDnK_Z' -H 'Content-Type application/json' -d '{
    //        "source": "walmart_product",
     //       "product_id": "15296401808",
     //       "parse": true
      //  }'
 /*
    private let oxyLabsApiKey = "0Ff1ouPK=bDnK_Z"
    private let oxyLabsUsername = "smaquois123"
    private let oxyLabsBaseURL = "https://developer.api.walmart.com"
    
    /// Search for products by name
    func searchProducts(query: String) async throws -> [WalmartProduct] {
        // URL encode the query
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw WalmartAPIError.invalidQuery
        }
        
        // Construct the URL
        // Example endpoint - verify with actual Walmart API docs
        //let urlString = "\(baseURL)/v1/search?query=\(encodedQuery)&format=json"
        //guard let url = URL(string: urlString) else {
        //    throw WalmartAPIError.invalidURL
        //}
        
        // Create request with API key
        //var request = URLRequest(url: url)
        //request.addValue(apiKey, forHTTPHeaderField: "apiKey")
        //request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // Perform request
        //let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check response
        //guard let httpResponse = response as? HTTPURLResponse else {
        //    throw WalmartAPIError.invalidResponse
        //}
        
        //guard httpResponse.statusCode == 200 else {
         //   throw WalmartAPIError.httpError(statusCode: httpResponse.statusCode)
        //}
        
        // Parse JSON
        //let decoder = JSONDecoder()
       // decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        //let searchResult = try decoder.decode(WalmartSearchResponse.self, from: data)
       // return searchResult.items
    }
    
    /// Get product by UPC barcode
    //func getProductByUPC(_ upc: String) async throws -> WalmartProduct {
        
        let urlString = "\(baseURL)/v1/items?upc=\(upc)&format=json"
        guard let url = URL(string: urlString) else {
            throw WalmartAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "apiKey")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WalmartAPIError.productNotFound
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let product = try decoder.decode(WalmartProduct.self, from: data)
        return product
         */
        //return
    //}
}

// MARK: - Response Models

struct WalmartSearchResponse: Codable {
    let items: [WalmartProduct]
    let totalResults: Int?
    let query: String?
}

struct WalmartProduct: Codable {
    let itemId: String
    let name: String
    let salePrice: Double
    let upc: String?
    let thumbnailImage: String?
    let productUrl: String?
    let stock: String?
    
    enum CodingKeys: String, CodingKey {
        case itemId
        case name
        case salePrice
        case upc
        case thumbnailImage
        case productUrl
        case stock
    }
}

enum WalmartAPIError: LocalizedError {
    case invalidQuery
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case productNotFound
    case apiKeyMissing
    
    var errorDescription: String? {
        switch self {
        case .invalidQuery:
            return "Invalid search query"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .productNotFound:
            return "Product not found"
        case .apiKeyMissing:
            return "API key is missing. Sign up at developer.walmart.com"
        }
    }
}

// MARK: - Integration with PriceComparisonService
/*
extension PriceComparisonService {
    /// Example of how to integrate Walmart API into price checking
    func checkWalmartPriceWithAPI(itemName: String, upc: String? = nil) async throws -> Double {
        let walmartAPI = WalmartAPIService()
        
        // Try UPC first if available (more accurate)
        if let upc = upc {
            do {
                let product = try await walmartAPI.getProductByUPC(upc)
                return product.salePrice
            } catch {
                print("UPC lookup failed, falling back to name search")
            }
        }
        
        // Fall back to name search
        let products = try await walmartAPI.searchProducts(query: itemName)
        
        // Return first result (in production, you might want fuzzy matching)
        guard let firstProduct = products.first else {
            throw PriceCheckError.itemNotFound
        }
        
        return firstProduct.salePrice
    }
}
*/
/*
 IMPLEMENTATION STEPS:
 
 1. Sign up at https://developer.walmart.com
 2. Get your API key
 3. Replace "YOUR_API_KEY_HERE" with your actual key
 4. Review Walmart's API documentation for exact endpoints
 5. Update the URL structure and request format as needed
 6. Test with sample queries
 
 BEST PRACTICES:
 
 - Store API keys securely (consider using Keychain)
 - Implement rate limiting (check Walmart's limits)
 - Cache results to minimize API calls
 - Handle errors gracefully
 - Implement retry logic with exponential backoff
 - Add unit tests for API interactions
 
 ALTERNATIVE APPROACHES:
 
 If Walmart API access is restricted or unavailable:
 
 1. Use third-party APIs:
    - Rainforest API (https://www.rainforestapi.com)
    - SerpAPI (https://serpapi.com) api key = 94deb564d802d01f867dece452ceec114961c634470d445872ed9ea1e68f0b50
    - Oxylabs (https://oxylabs.io)
 
 2. Implement with other retailer APIs:
    - Best Buy API (more accessible)
    - Target (partner APIs)
    - Amazon Product Advertising API
 
 3. Consider a hybrid approach:
    - Use APIs where available
    - Allow manual price entry
    - Implement price history tracking
 */
