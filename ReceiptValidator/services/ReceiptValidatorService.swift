//
//  ReceiptValidatorService.swift
//  ReceiptValidator
//
//  Created by JC Smith on 1/3/26.
//

import Foundation
internal import Combine

/// Service for validating receipt prices during the review process
/// Uses HybridPriceValidationService which combines UPC lookup with Apify
@MainActor
class ReceiptValidatorService: ObservableObject {
    @Published var isValidating = false
    @Published var validationProgress: Double = 0.0
    
    private let hybridService: HybridPriceValidationService
    
    init() {
        self.hybridService = HybridPriceValidationService()
    }
    
    /// Validates scanned items against retailer prices
    /// Returns validation results for display
    func validateReceipt(_ scannedData: ScannedReceiptData, retailer: RetailerType) async throws -> ValidationSummary {
        isValidating = true
        validationProgress = 0.0
        
        defer {
            isValidating = false
            validationProgress = 0.0
        }
        
        var results: [ItemValidationResult] = []
        let totalItems = scannedData.items.count
        
        // Convert ScannedItems to temporary ReceiptItems for validation
        for (index, scannedItem) in scannedData.items.enumerated() {
            // Update progress
            validationProgress = Double(index) / Double(totalItems)
            
            // Create temporary ReceiptItem
            let tempItem = ReceiptItem(
                name: scannedItem.name,
                price: scannedItem.price,
                upc: scannedItem.sku // Use SKU as UPC if available
            )
            
            do {
                let validationResult = try await hybridService.validateItemPrice(
                    item: tempItem,
                    retailer: retailer.displayName
                )
                
                results.append(ItemValidationResult(
                    scannedItem: scannedItem,
                    priceValidationResult: validationResult
                ))
                
                // Rate limiting
                if index < totalItems - 1 {
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                }
            } catch {
                // Add failed result
                results.append(ItemValidationResult(
                    scannedItem: scannedItem,
                    priceValidationResult: PriceValidationResult(
                        itemName: scannedItem.name,
                        receiptPrice: scannedItem.price,
                        onlinePrice: nil,
                        priceDifference: nil,
                        percentDifference: nil,
                        retailer: retailer.displayName,
                        productURL: nil,
                        validationMethod: .failed,
                        error: error.localizedDescription
                    )
                ))
            }
        }
        
        validationProgress = 1.0
        
        return ValidationSummary(
            storeName: scannedData.storeName ?? retailer.displayName,
            items: results,
            totalAmount: scannedData.totalAmount
        )
    }
}

/// Summary of validation results for scanned receipt
struct ValidationSummary {
    let storeName: String
    let items: [ItemValidationResult]
    let totalAmount: Double?
    
    var successfulValidations: Int {
        items.filter { $0.priceValidationResult.onlinePrice != nil }.count
    }
    
    var totalPriceDifference: Double {
        items.compactMap { $0.priceValidationResult.priceDifference }.reduce(0, +)
    }
    
    var flaggedItems: [ItemValidationResult] {
        items.filter { 
            guard let diff = $0.priceValidationResult.priceDifference else { return false }
            return diff > 0 && $0.priceValidationResult.isSignificantDifference
        }
    }
}

/// Result of validating a single scanned item
struct ItemValidationResult: Identifiable {
    let id = UUID()
    let scannedItem: ScannedItem
    let priceValidationResult: PriceValidationResult
}
