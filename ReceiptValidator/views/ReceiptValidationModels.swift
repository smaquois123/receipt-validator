//
//  ReceiptValidationModels.swift
//  ReceiptValidator
//
//  Created by JC Smith on 1/3/26.
//

import Foundation

// MARK: - Receipt Validation Models

/// Result of validating an entire receipt
struct ReceiptValidationResult {
    let storeName: String?
    let items: [ValidatedItem]
    let totalAmount: Double?
    let rawText: String
    
    var validItems: [ValidatedItem] {
        items.filter { $0.isValid }
    }
    
    var invalidItems: [ValidatedItem] {
        items.filter { !$0.isValid }
    }
    
    var suspiciousItems: [ValidatedItem] {
        items.filter { $0.confidence < 0.7 && $0.isValid }
    }
    
    var validationRate: Double {
        guard !items.isEmpty else { return 0 }
        return Double(validItems.count) / Double(items.count)
    }
}

/// Result of validating a single item
struct ValidatedItem: Identifiable {
    let id = UUID()
    let item: ScannedItem
    let isValid: Bool
    let confidence: Double
    let validationMessage: String?
    let currentOnlinePrice: Double?
    let priceDifference: Double?
    let productURL: String?
    let inStock: Bool?
    
    init(
        item: ScannedItem,
        isValid: Bool,
        confidence: Double,
        validationMessage: String? = nil,
        currentOnlinePrice: Double? = nil,
        priceDifference: Double? = nil,
        productURL: String? = nil,
        inStock: Bool? = nil
    ) {
        self.item = item
        self.isValid = isValid
        self.confidence = confidence
        self.validationMessage = validationMessage
        self.currentOnlinePrice = currentOnlinePrice
        self.priceDifference = priceDifference
        self.productURL = productURL
        self.inStock = inStock
    }
}

// MARK: - Charge Validation Models (for ReceiptValidationView)

/// Summary of receipt charge validation
struct ReceiptValidationSummary {
    let receipt: Receipt
    let itemResults: [ChargeValidationResult]
    let validationDate: Date
    
    var flaggedItems: [ChargeValidationResult] {
        itemResults.filter { $0.shouldFlag }
    }
    
    var totalItemsValidated: Int {
        itemResults.count
    }
    
    var itemsWithinTolerance: Int {
        itemResults.filter { 
            $0.validationStatus == .exactMatch ||
            $0.validationStatus == .withinTolerance ||
            $0.validationStatus == .receiptLower
        }.count
    }
    
    var possibleOvercharges: Int {
        itemResults.filter { $0.validationStatus == .possibleOvercharge }.count
    }
    
    var significantDiscrepancies: Int {
        itemResults.filter { $0.validationStatus == .significantDiscrepancy }.count
    }
    
    var totalPotentialOvercharge: Double {
        flaggedItems
            .compactMap { $0.priceDifference }
            .filter { $0 > 0 }
            .reduce(0, +)
    }
    
    var overallStatus: OverallReceiptStatus {
        if significantDiscrepancies > 0 {
            return .hasSignificantIssues
        } else if possibleOvercharges > 0 {
            return .hasPossibleIssues
        } else if totalItemsValidated > 0 && itemsWithinTolerance == totalItemsValidated {
            return .allGood
        } else {
            return .needsReview
        }
    }
}

/// Result of validating a single charge
struct ChargeValidationResult {
    let item: ReceiptItem
    let websitePrice: Double?
    let priceDifference: Double?
    let percentDifference: Double?
    let validationStatus: ValidationStatus
    let confidence: ConfidenceLevel
    let notes: String
    let productURL: String?
    
    var shouldFlag: Bool {
        validationStatus == .possibleOvercharge ||
        validationStatus == .significantDiscrepancy
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
    
    var statusIcon: String {
        switch validationStatus {
        case .exactMatch: return "✅"
        case .withinTolerance: return "✓"
        case .receiptLower: return "💰"
        case .possibleOvercharge: return "⚠️"
        case .significantDiscrepancy: return "🚨"
        case .notFound: return "🔍"
        case .error: return "❌"
        }
    }
}

// MARK: - Enums

enum ValidationStatus {
    case exactMatch
    case withinTolerance
    case receiptLower
    case possibleOvercharge
    case significantDiscrepancy
    case notFound
    case error
}

enum ConfidenceLevel {
    case high
    case medium
    case low
    case none
}

enum OverallReceiptStatus {
    case allGood
    case hasPossibleIssues
    case hasSignificantIssues
    case needsReview
    
    var displayText: String {
        switch self {
        case .allGood:
            return "All charges appear correct"
        case .hasPossibleIssues:
            return "Some items may be overcharged - review recommended"
        case .hasSignificantIssues:
            return "Significant billing errors detected - contact store"
        case .needsReview:
            return "Manual review needed"
        }
    }
}
