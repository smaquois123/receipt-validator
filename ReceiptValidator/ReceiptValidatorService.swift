//
//  ReceiptValidatorService.swift
//  ReceiptValidator
//
//  Created by JC Smith on 12/26/25.
//

import Foundation
internal import Combine

/// Service for validating receipt items against retailer websites using FireCrawl
///
/// This service searches for products using UPC/barcode when available (highly accurate),
/// falling back to product name search when UPC is not available.
/// 
/// **Note**: For best results, ensure ScannedItem includes a `upc`, `itemId`, or `barcode` property
/// extracted from the receipt's barcode data.
@MainActor
class ReceiptValidatorService: ObservableObject {
    @Published var validationProgress: Double = 0.0
    @Published var isValidating = false
    @Published var validationErrors: [String] = []
    
    private let fireCrawl: FireCrawlService
    
    init(fireCrawlAPIKey: String = "") {
        self.fireCrawl = FireCrawlService(apiKey: fireCrawlAPIKey)
    }
    
    /// Validates all items in a scanned receipt against current online prices
    func validateReceipt(_ receipt: ScannedReceiptData, retailer: RetailerType) async throws -> ReceiptValidationResult {
        isValidating = true
        validationProgress = 0.0
        validationErrors.removeAll()
        defer { isValidating = false }
        
        var validatedItems: [ValidatedItem] = []
        let totalItems = receipt.items.count
        
        for (index, item) in receipt.items.enumerated() {
            let validatedItem = await validateItem(item, retailer: retailer)
            validatedItems.append(validatedItem)
            
            // Update progress
            validationProgress = Double(index + 1) / Double(totalItems)
            
            // Add delay to avoid rate limiting
            if index < totalItems - 1 {
                try? await Task.sleep(for: .seconds(1))
            }
        }
        
        return ReceiptValidationResult(
            storeName: receipt.storeName,
            items: validatedItems,
            totalAmount: receipt.totalAmount,
            rawText: receipt.rawText
        )
    }
    
    /// Validates a single item against the retailer's product database
    private func validateItem(_ item: ScannedItem, retailer: RetailerType) async -> ValidatedItem {
        switch retailer {
        case .walmart:
            return await validateWalmartItem(item)
        case .target:
            return await validateTargetItem(item)
        case .costco:
            return await validateCostcoItem(item)
        default:
            return await validateGenericItem(item, retailer: retailer)
        }
    }
    
    /// Validates an item using Walmart's website via FireCrawl
    private func validateWalmartItem(_ item: ScannedItem) async -> ValidatedItem {
        do {
            // Check if item has a UPC/itemId field using Mirror for reflection
            var upc: String? = nil
            let mirror = Mirror(reflecting: item)
            for child in mirror.children {
                if child.label == "upc" || child.label == "itemId" || child.label == "barcode" {
                    upc = child.value as? String
                    break
                }
            }
            
            // Pass UPC if available for more accurate search
            guard let productData = try await fireCrawl.scrapeWalmartProduct(
                searchQuery: item.name,
                upc: upc
            ) else {
                return ValidatedItem(
                    item: item,
                    isValid: false,
                    confidence: 0.2,
                    validationMessage: upc != nil ? 
                        "Product with UPC \(upc!) not found on Walmart.com" :
                        "Product '\(item.name)' not found on Walmart.com",
                    currentOnlinePrice: nil,
                    priceDifference: nil
                )
            }
            
            // Calculate price difference
            let priceDiff = item.price - productData.price
            let percentageDiff = abs(priceDiff / item.price * 100)
            
            // Determine if prices match within reasonable tolerance (±10%)
            let isValid = percentageDiff <= 10.0
            
            // Higher confidence if product name matches well
            let confidence = calculateNameMatchConfidence(
                receiptName: item.name,
                productName: productData.name
            )
            
            let message: String
            if priceDiff > 0 {
                message = "You paid $\(String(format: "%.2f", abs(priceDiff))) more than current online price"
            } else if priceDiff < 0 {
                message = "You paid $\(String(format: "%.2f", abs(priceDiff))) less than current online price"
            } else {
                message = "Price matches current online price"
            }
            
            return ValidatedItem(
                item: item,
                isValid: isValid,
                confidence: confidence,
                validationMessage: message,
                currentOnlinePrice: productData.price,
                priceDifference: priceDiff,
                productURL: productData.url,
                inStock: productData.inStock
            )
            
        } catch {
            let errorMsg = "Failed to check Walmart price: \(error.localizedDescription)"
            validationErrors.append(errorMsg)
            
            return ValidatedItem(
                item: item,
                isValid: false,
                confidence: 0.0,
                validationMessage: errorMsg,
                currentOnlinePrice: nil,
                priceDifference: nil
            )
        }
    }
    
    /// Validates an item using Target's website via FireCrawl
    private func validateTargetItem(_ item: ScannedItem) async -> ValidatedItem {
        do {
            // Check if item has a UPC/itemId field using Mirror for reflection
            var upc: String? = nil
            let mirror = Mirror(reflecting: item)
            for child in mirror.children {
                if child.label == "upc" || child.label == "itemId" || child.label == "barcode" {
                    upc = child.value as? String
                    break
                }
            }
            
            guard let productData = try await fireCrawl.scrapeTargetProduct(
                searchQuery: item.name,
                upc: upc
            ) else {
                return ValidatedItem(
                    item: item,
                    isValid: false,
                    confidence: 0.2,
                    validationMessage: upc != nil ?
                        "Product with UPC \(upc!) not found on Target.com" :
                        "Product '\(item.name)' not found on Target.com",
                    currentOnlinePrice: nil,
                    priceDifference: nil
                )
            }
            
            let priceDiff = item.price - productData.price
            let percentageDiff = abs(priceDiff / item.price * 100)
            let isValid = percentageDiff <= 10.0
            
            let confidence = calculateNameMatchConfidence(
                receiptName: item.name,
                productName: productData.name
            )
            
            let message: String
            if priceDiff > 0 {
                message = "You paid $\(String(format: "%.2f", abs(priceDiff))) more than current online price"
            } else if priceDiff < 0 {
                message = "You paid $\(String(format: "%.2f", abs(priceDiff))) less than current online price"
            } else {
                message = "Price matches current online price"
            }
            
            return ValidatedItem(
                item: item,
                isValid: isValid,
                confidence: confidence,
                validationMessage: message,
                currentOnlinePrice: productData.price,
                priceDifference: priceDiff,
                productURL: productData.url
            )
            
        } catch {
            let errorMsg = "Failed to check Target price: \(error.localizedDescription)"
            validationErrors.append(errorMsg)
            
            return ValidatedItem(
                item: item,
                isValid: false,
                confidence: 0.0,
                validationMessage: errorMsg,
                currentOnlinePrice: nil,
                priceDifference: nil
            )
        }
    }
    
    /// Validates an item using Costco's website via FireCrawl
    private func validateCostcoItem(_ item: ScannedItem) async -> ValidatedItem {
        do {
            guard let productData = try await fireCrawl.scrapeCostcoProduct(searchQuery: item.name) else {
                return ValidatedItem(
                    item: item,
                    isValid: false,
                    confidence: 0.2,
                    validationMessage: "Product not found on Costco.com",
                    currentOnlinePrice: nil,
                    priceDifference: nil
                )
            }
            
            let priceDiff = item.price - productData.price
            let percentageDiff = abs(priceDiff / item.price * 100)
            let isValid = percentageDiff <= 10.0
            
            let confidence = calculateNameMatchConfidence(
                receiptName: item.name,
                productName: productData.name
            )
            
            let message: String
            if priceDiff > 0 {
                message = "You paid $\(String(format: "%.2f", abs(priceDiff))) more than current online price"
            } else if priceDiff < 0 {
                message = "You paid $\(String(format: "%.2f", abs(priceDiff))) less than current online price"
            } else {
                message = "Price matches current online price"
            }
            
            return ValidatedItem(
                item: item,
                isValid: isValid,
                confidence: confidence,
                validationMessage: message,
                currentOnlinePrice: productData.price,
                priceDifference: priceDiff,
                productURL: productData.url
            )
            
        } catch {
            let errorMsg = "Failed to check Costco price: \(error.localizedDescription)"
            validationErrors.append(errorMsg)
            
            return ValidatedItem(
                item: item,
                isValid: false,
                confidence: 0.0,
                validationMessage: errorMsg,
                currentOnlinePrice: nil,
                priceDifference: nil
            )
        }
    }
    
    /// Generic validation for other retailers
    private func validateGenericItem(_ item: ScannedItem, retailer: RetailerType) async -> ValidatedItem {
        return ValidatedItem(
            item: item,
            isValid: false,
            confidence: 0.0,
            validationMessage: "Price validation not yet supported for \(retailer.displayName)",
            currentOnlinePrice: nil,
            priceDifference: nil
        )
    }
    
    /// Calculates confidence based on how well the receipt name matches the product name
    private func calculateNameMatchConfidence(receiptName: String, productName: String) -> Double {
        let receipt = receiptName.lowercased()
        let product = productName.lowercased()
        
        // Remove common words
        let commonWords = ["the", "a", "an", "of", "and", "or"]
        let receiptWords = Set(receipt.components(separatedBy: .whitespaces)
            .filter { !commonWords.contains($0) && $0.count > 2 })
        let productWords = Set(product.components(separatedBy: .whitespaces)
            .filter { !commonWords.contains($0) && $0.count > 2 })
        
        guard !receiptWords.isEmpty else { return 0.5 }
        
        // Calculate word overlap
        let intersection = receiptWords.intersection(productWords)
        let confidence = Double(intersection.count) / Double(max(receiptWords.count, productWords.count))
        
        // Boost confidence if one contains the other
        if product.contains(receipt) || receipt.contains(product) {
            return min(1.0, confidence + 0.3)
        }
        
        return max(0.3, min(0.95, confidence))
    }
}

// MARK: - Supporting Types

struct ReceiptValidationResult {
    var storeName: String?
    var items: [ValidatedItem]
    var totalAmount: Double?
    var rawText: String
    
    /// Returns only items that passed validation
    var validItems: [ValidatedItem] {
        items.filter { $0.isValid }
    }
    
    /// Returns items that failed validation
    var invalidItems: [ValidatedItem] {
        items.filter { !$0.isValid }
    }
    
    /// Returns items with low confidence scores
    var suspiciousItems: [ValidatedItem] {
        items.filter { $0.confidence < 0.6 }
    }
    
    /// Overall validation success rate
    var validationRate: Double {
        guard !items.isEmpty else { return 0.0 }
        return Double(validItems.count) / Double(items.count)
    }
}

struct ValidatedItem: Identifiable {
    var id = UUID()
    var item: ScannedItem
    var isValid: Bool
    var confidence: Double // 0.0 to 1.0
    var validationMessage: String?
    var currentOnlinePrice: Double?
    var priceDifference: Double? // Positive = paid more, Negative = paid less
    var productURL: String?
    var inStock: Bool?
    
    var statusColor: String {
        if isValid && confidence > 0.7 {
            return "green"
        } else if confidence > 0.5 {
            return "yellow"
        } else {
            return "red"
        }
    }
    
    var priceStatusColor: String {
        guard let diff = priceDifference else { return "gray" }
        if diff > 0 {
            return "red" // Paid more
        } else if diff < 0 {
            return "green" // Paid less
        } else {
            return "blue" // Exact match
        }
    }
}
