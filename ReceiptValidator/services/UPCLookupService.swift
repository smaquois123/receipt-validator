//
//  UPCLookupService.swift
//  ReceiptValidator
//
//  Created by JC Smith on 1/2/26.
//

import Foundation

/// Service for looking up product information by UPC/barcode
/// Provides multiple strategies for efficient product matching
class UPCLookupService {
    
    // MARK: - API Options
    
    /// Different UPC lookup services available
    enum LookupProvider {
        case upcItemDB           // Free tier: 100 requests/day
        case barcodeLookup       // Paid: $30/month for 500 requests/day
        case upcDatabase         // Free tier available
        case openFoodFacts       // Free for food products
        case walmart             // Direct Walmart API (requires approval)
        case hybrid              // Try multiple sources
    }
    
    private let provider: LookupProvider
    private let apiKeys: [String: String]
    
    init(provider: LookupProvider = .hybrid, apiKeys: [String: String] = [:]) {
        self.provider = provider
        self.apiKeys = apiKeys
    }
    
    // MARK: - Public Methods
    
    /// Look up product by UPC code
    /// - Parameters:
    ///   - upc: The UPC/barcode string
    ///   - retailer: Optional retailer hint for better matching
    /// - Returns: Product information including current price
    func lookupProduct(upc: String, retailer: String? = nil) async throws -> UPCProductResult {
        switch provider {
        case .upcItemDB:
            return try await lookupUPCItemDB(upc: upc)
        case .barcodeLookup:
            return try await lookupBarcodeLookup(upc: upc)
        case .upcDatabase:
            return try await lookupUPCDatabase(upc: upc)
        case .openFoodFacts:
            return try await lookupOpenFoodFacts(upc: upc)
        case .walmart:
            return try await lookupWalmart(upc: upc)
        case .hybrid:
            return try await lookupHybrid(upc: upc, retailer: retailer)
        }
    }
    
    // MARK: - Individual Services
    
    /// UPCItemDB API (Free tier: 100 requests/day)
    /// Sign up at: https://www.upcitemdb.com/
    private func lookupUPCItemDB(upc: String) async throws -> UPCProductResult {
        guard let apiKey = apiKeys["upcItemDB"] else {
            throw UPCLookupError.apiKeyMissing("UPCItemDB")
        }
        
        let urlString = "https://api.upcitemdb.com/prod/trial/lookup?upc=\(upc)"
        guard let url = URL(string: urlString) else {
            throw UPCLookupError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "user_key")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw UPCLookupError.apiError("UPCItemDB request failed")
        }
        
        let result = try JSONDecoder().decode(UPCItemDBResponse.self, from: data)
        
        guard let item = result.items.first else {
            throw UPCLookupError.productNotFound
        }
        
        return UPCProductResult(
            upc: upc,
            title: item.title,
            brand: item.brand,
            price: nil, // UPCItemDB doesn't provide current prices
            imageURL: item.images?.first,
            retailer: nil,
            productURL: nil
        )
    }
    
    /// Barcode Lookup API (Paid service, most comprehensive)
    /// Sign up at: https://www.barcodelookup.com/api
    private func lookupBarcodeLookup(upc: String) async throws -> UPCProductResult {
        guard let apiKey = apiKeys["barcodeLookup"] else {
            throw UPCLookupError.apiKeyMissing("BarcodeLookup")
        }
        
        let urlString = "https://api.barcodelookup.com/v3/products?barcode=\(upc)&key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw UPCLookupError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let result = try JSONDecoder().decode(BarcodeLookupResponse.self, from: data)
        
        guard let product = result.products.first else {
            throw UPCLookupError.productNotFound
        }
        
        return UPCProductResult(
            upc: upc,
            title: product.title,
            brand: product.brand,
            price: product.stores?.first?.price,
            imageURL: product.images?.first,
            retailer: product.stores?.first?.name,
            productURL: product.stores?.first?.link
        )
    }
    
    /// UPC Database API (Free tier available)
    /// Sign up at: https://upcdatabase.org/
    private func lookupUPCDatabase(upc: String) async throws -> UPCProductResult {
        guard let apiKey = apiKeys["upcDatabase"] else {
            throw UPCLookupError.apiKeyMissing("UPCDatabase")
        }
        
        let urlString = "https://api.upcdatabase.org/product/\(upc)?apikey=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw UPCLookupError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let result = try JSONDecoder().decode(UPCDatabaseResponse.self, from: data)
        
        return UPCProductResult(
            upc: upc,
            title: result.title,
            brand: result.brand,
            price: nil,
            imageURL: nil,
            retailer: nil,
            productURL: nil
        )
    }
    
    /// Open Food Facts API (Free, but only for food products)
    /// No API key required: https://world.openfoodfacts.org/
    private func lookupOpenFoodFacts(upc: String) async throws -> UPCProductResult {
        let urlString = "https://world.openfoodfacts.org/api/v2/product/\(upc).json"
        guard let url = URL(string: urlString) else {
            throw UPCLookupError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let result = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)
        
        guard result.status == 1, let product = result.product else {
            throw UPCLookupError.productNotFound
        }
        
        return UPCProductResult(
            upc: upc,
            title: product.productName ?? "Unknown",
            brand: product.brands,
            price: nil,
            imageURL: product.imageURL,
            retailer: nil,
            productURL: nil
        )
    }
    
    /// Walmart API (Requires approval, but direct access to Walmart data)
    /// Apply at: https://developer.walmart.com/
    private func lookupWalmart(upc: String) async throws -> UPCProductResult {
        guard let apiKey = apiKeys["walmart"] else {
            throw UPCLookupError.apiKeyMissing("Walmart")
        }
        
        // Walmart API endpoint for UPC lookup
        let urlString = "https://developer.api.walmart.com/api-proxy/service/affil/product/v2/items?upc=\(upc)"
        guard let url = URL(string: urlString) else {
            throw UPCLookupError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "WM_SEC.KEY_VERSION")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let result = try JSONDecoder().decode(WalmartAPIResponse.self, from: data)
        
        guard let item = result.items.first else {
            throw UPCLookupError.productNotFound
        }
        
        return UPCProductResult(
            upc: upc,
            title: item.name,
            brand: item.brandName,
            price: item.salePrice,
            imageURL: item.thumbnailImage,
            retailer: "Walmart",
            productURL: item.productURL
        )
    }
    
    /// Hybrid approach: Try multiple sources in order of preference
    private func lookupHybrid(upc: String, retailer: String?) async throws -> UPCProductResult {
        // Try retailer-specific APIs first if we know the retailer
        if let retailer = retailer?.lowercased() {
            if retailer.contains("walmart"), apiKeys["walmart"] != nil {
                if let result = try? await lookupWalmart(upc: upc) {
                    return result
                }
            }
        }
        
        // Try free services first
        if apiKeys["upcItemDB"] != nil {
            if let result = try? await lookupUPCItemDB(upc: upc) {
                return result
            }
        }
        
        if let result = try? await lookupOpenFoodFacts(upc: upc) {
            return result
        }
        
        // Try paid services if available
        if apiKeys["barcodeLookup"] != nil {
            if let result = try? await lookupBarcodeLookup(upc: upc) {
                return result
            }
        }
        
        if apiKeys["upcDatabase"] != nil {
            if let result = try? await lookupUPCDatabase(upc: upc) {
                return result
            }
        }
        
        throw UPCLookupError.productNotFound
    }
}

// MARK: - Models

struct UPCProductResult {
    let upc: String
    let title: String
    let brand: String?
    let price: Double?
    let imageURL: String?
    let retailer: String?
    let productURL: String?
}

// Response models for different APIs
struct UPCItemDBResponse: Codable {
    let items: [UPCItemDBItem]
}

struct UPCItemDBItem: Codable {
    let title: String
    let brand: String?
    let images: [String]?
}

struct BarcodeLookupResponse: Codable {
    let products: [BarcodeLookupProduct]
}

struct BarcodeLookupProduct: Codable {
    let title: String
    let brand: String?
    let images: [String]?
    let stores: [BarcodeLookupStore]?
}

struct BarcodeLookupStore: Codable {
    let name: String
    let price: Double?
    let link: String?
}

struct UPCDatabaseResponse: Codable {
    let title: String
    let brand: String?
}

struct OpenFoodFactsResponse: Codable {
    let status: Int
    let product: OpenFoodFactsProduct?
}

struct OpenFoodFactsProduct: Codable {
    let productName: String?
    let brands: String?
    let imageURL: String?
    
    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brands
        case imageURL = "image_url"
    }
}

struct WalmartAPIResponse: Codable {
    let items: [WalmartItem]
}

struct WalmartItem: Codable {
    let name: String
    let brandName: String?
    let salePrice: Double?
    let thumbnailImage: String?
    let productURL: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case brandName
        case salePrice
        case thumbnailImage
        case productURL = "productUrl"
    }
}

enum UPCLookupError: LocalizedError {
    case apiKeyMissing(String)
    case invalidURL
    case apiError(String)
    case productNotFound
    case noProvidersAvailable
    
    var errorDescription: String? {
        switch self {
        case .apiKeyMissing(let service):
            return "\(service) API key is missing"
        case .invalidURL:
            return "Invalid URL"
        case .apiError(let message):
            return "API error: \(message)"
        case .productNotFound:
            return "Product not found"
        case .noProvidersAvailable:
            return "No UPC lookup providers configured"
        }
    }
}
