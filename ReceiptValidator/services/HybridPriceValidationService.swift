//
//  HybridPriceValidationService.swift
//  ReceiptValidator
//
//  Created by JC Smith on 1/2/26.
//

import Foundation

/// Combines UPC lookup with Apify for efficient price validation
/// Strategy: Use UPC when available for better accuracy and lower cost
class HybridPriceValidationService {
    
    private let upcService: UPCLookupService
    private let apifyService: ApifyWalmartService
    private let useUPCWhenAvailable: Bool
    
    init(
        upcAPIKeys: [String: String] = AppConfiguration.upcAPIKeys,
        apifyAPIToken: String = AppConfiguration.ApifyAPIToken,
        useUPCWhenAvailable: Bool = AppConfiguration.preferUPCLookup
    ) {
        self.upcService = UPCLookupService(provider: .hybrid, apiKeys: upcAPIKeys)
        self.apifyService = ApifyWalmartService(apiToken: apifyAPIToken)
        self.useUPCWhenAvailable = useUPCWhenAvailable
    }
    
    // MARK: - Public Methods
    
    /// Validates receipt item price against current online price
    /// Uses the most efficient method available
    func validateItemPrice(item: ReceiptItem, retailer: String? = nil) async throws -> PriceValidationResult {
        // Strategy 1: Try UPC lookup if available and enabled
        if let upc = item.upc, !upc.isEmpty, useUPCWhenAvailable, AppConfiguration.isUPCLookupConfigured {
            print("🔍 Attempting UPC lookup for: \(item.name) (UPC: \(upc))")
            
            do {
                let result = try await validateWithUPC(
                    upc: upc,
                    itemName: item.name,
                    receiptPrice: item.price,
                    retailer: retailer
                )
                
                print("✅ UPC lookup successful!")
                return result
                
            } catch {
                print("⚠️ UPC lookup failed (\(error.localizedDescription)), falling back to name search")
            }
        }
        
        // Strategy 2: Fall back to product name search with Apify
        print("🔍 Using name-based search for: \(item.name)")
        return try await validateWithProductName(
            name: item.name,
            receiptPrice: item.price,
            upcToVerify: item.upc,
            retailer: retailer
        )
    }
    
    /// Batch validate multiple items efficiently
    func validateItems(_ items: [ReceiptItem], retailer: String? = nil) async throws -> [PriceValidationResult] {
        var results: [PriceValidationResult] = []
        
        // Sort items: UPC-available items first (faster/cheaper to process)
        let sortedItems = items.sorted { ($0.upc != nil && !$0.upc!.isEmpty) && ($1.upc == nil || $1.upc!.isEmpty) }
        
        for item in sortedItems {
            do {
                let result = try await validateItemPrice(item: item, retailer: retailer)
                results.append(result)
                
                // Rate limiting delay
                try await Task.sleep(nanoseconds: UInt64(AppConfiguration.validationDelay * 1_000_000_000))
                
            } catch {
                print("❌ Failed to validate \(item.name): \(error.localizedDescription)")
                
                // Add failed result
                results.append(PriceValidationResult(
                    itemName: item.name,
                    receiptPrice: item.price,
                    onlinePrice: nil,
                    priceDifference: nil,
                    percentDifference: nil,
                    retailer: retailer,
                    productURL: nil,
                    validationMethod: .failed,
                    error: error.localizedDescription
                ))
            }
        }
        
        return results
    }
    
    // MARK: - Private Validation Methods
    
    /// Validate using UPC lookup (preferred method)
    private func validateWithUPC(
        upc: String,
        itemName: String,
        receiptPrice: Double,
        retailer: String?
    ) async throws -> PriceValidationResult {
        
        // Step 1: Look up product by UPC
        let upcResult = try await upcService.lookupProduct(upc: upc, retailer: retailer)
        
        print("📦 Found product: \(upcResult.title)")
        
        // Step 2a: If we got a price directly from UPC API, use it
        if let price = upcResult.price {
            print("💰 Got price from UPC API: $\(price)")
            
            return PriceValidationResult(
                itemName: upcResult.title,
                receiptPrice: receiptPrice,
                onlinePrice: price,
                priceDifference: receiptPrice - price,
                percentDifference: ((receiptPrice - price) / receiptPrice) * 100,
                retailer: upcResult.retailer ?? retailer,
                productURL: upcResult.productURL,
                validationMethod: .upcDirect,
                error: nil
            )
        }
        
        // Step 2b: If we have a product URL, scrape it directly with Apify
        if let productURL = upcResult.productURL {
            print("🔗 Scraping product page: \(productURL)")
            
            // Scrape the specific product page (much faster than searching)
            if let productData = try await scrapeProductPage(url: productURL) {
                return PriceValidationResult(
                    itemName: productData.name,
                    receiptPrice: receiptPrice,
                    onlinePrice: productData.price,
                    priceDifference: receiptPrice - productData.price,
                    percentDifference: ((receiptPrice - productData.price) / receiptPrice) * 100,
                    retailer: upcResult.retailer ?? retailer,
                    productURL: productData.url,
                    validationMethod: .upcWithScrape,
                    error: nil
                )
            }
        }
        
        // Step 2c: Use the accurate product name from UPC for Apify search
        print("🔍 Searching with UPC-verified name: \(upcResult.title)")
        
        return try await validateWithProductName(
            name: upcResult.title,  // Use accurate name from UPC database
            receiptPrice: receiptPrice,
            upcToVerify: upc,  // Verify we get the right product
            retailer: retailer
        )
    }
    
    /// Validate using product name search (fallback method)
    private func validateWithProductName(
        name: String,
        receiptPrice: Double,
        upcToVerify: String?,
        retailer: String?
    ) async throws -> PriceValidationResult {
        
        // Use Apify to search for the product
        // For now, we only support Walmart through Apify
        // In the future, could add other retailer scrapers
        
        let product: ApifyWalmartProduct?
        
        // Try UPC search first if available
        if let upc = upcToVerify, !upc.isEmpty {
            product = try await apifyService.searchByUPC(upc)
        } else {
            // Fallback to name search
            product = try await apifyService.searchByName(name)
        }
        
        guard let foundProduct = product else {
            throw PriceValidationError.productNotFound
        }
        
        // Verify UPC match if we have one to check
        if let expectedUPC = upcToVerify,
           let foundUPC = foundProduct.upc,
           expectedUPC != foundUPC {
            print("⚠️ UPC mismatch! Expected: \(expectedUPC), Found: \(foundUPC)")
        }
        
        return PriceValidationResult(
            itemName: foundProduct.name,
            receiptPrice: receiptPrice,
            onlinePrice: foundProduct.price,
            priceDifference: receiptPrice - foundProduct.price,
            percentDifference: ((receiptPrice - foundProduct.price) / receiptPrice) * 100,
            retailer: retailer ?? "Walmart",
            productURL: foundProduct.url,
            validationMethod: .nameBased,
            error: nil
        )
    }
    
    /// Scrape a specific product page directly using Apify
    private func scrapeProductPage(url: String) async throws -> ApifyWalmartProduct? {
        // Use Apify to scrape the specific product page
        return try await apifyService.scrapeProductPage(url: url)
    }
}

// MARK: - Models

struct PriceValidationResult {
    let itemName: String
    let receiptPrice: Double
    let onlinePrice: Double?
    let priceDifference: Double?
    let percentDifference: Double?
    let retailer: String?
    let productURL: String?
    let validationMethod: ValidationMethod
    let error: String?
    
    var didOverpay: Bool {
        guard let diff = priceDifference else { return false }
        return diff > 0
    }
    
    var isSignificantDifference: Bool {
        guard let percentDiff = percentDifference else { return false }
        return abs(percentDiff) > (AppConfiguration.priceTolerancePercentage * 100)
    }
    
    var formattedDifference: String {
        guard let diff = priceDifference else { return "N/A" }
        let prefix = diff > 0 ? "+" : ""
        return "\(prefix)$\(String(format: "%.2f", diff))"
    }
    
    var formattedPercentDifference: String {
        guard let percent = percentDifference else { return "N/A" }
        let prefix = percent > 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.1f", percent))%"
    }
}

enum ValidationMethod: String {
    case upcDirect = "UPC Direct"           // Got price directly from UPC API
    case upcWithScrape = "UPC + Scrape"     // UPC gave us URL, scraped price
    case nameBased = "Name Search"           // Searched by product name
    case failed = "Failed"
    
    var icon: String {
        switch self {
        case .upcDirect: return "⚡️"
        case .upcWithScrape: return "🔗"
        case .nameBased: return "🔍"
        case .failed: return "❌"
        }
    }
}

enum PriceValidationError: LocalizedError {
    case productNotFound
    case upcMismatch
    case noServicesConfigured
    case rateLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product not found online"
        case .upcMismatch:
            return "Found product doesn't match UPC code"
        case .noServicesConfigured:
            return "No price validation services configured"
        case .rateLimitExceeded:
            return "Rate limit exceeded, please try again later"
        }
    }
}

// MARK: - Usage Example
/*
 // In your view or service:
 
 let validationService = HybridPriceValidationService()
 
 // Single item
 let result = try await validationService.validateItemPrice(
     item: receiptItem,
     retailer: receipt.storeName
 )
 
 print("Result: \(result.validationMethod.icon) \(result.itemName)")
 print("Receipt: $\(result.receiptPrice)")
 if let online = result.onlinePrice {
     print("Online: $\(online)")
     print("Difference: \(result.formattedDifference) (\(result.formattedPercentDifference))")
 }
 
 // Batch processing
 let results = try await validationService.validateItems(
     receipt.items,
     retailer: receipt.storeName
 )
 
 // Analyze results
 let successful = results.filter { $0.onlinePrice != nil }
 let upcBased = results.filter { $0.validationMethod == .upcDirect || $0.validationMethod == .upcWithScrape }
 
 print("Success rate: \(successful.count)/\(results.count)")
 print("UPC-based: \(upcBased.count)/\(results.count) (faster/cheaper!)")
 */
