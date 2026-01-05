//
//  PriceValidationService.swift
//  ReceiptValidator
//
//  Created by JC Smith on 1/3/26.
//

import Foundation

/// Simplified price validation service using only Apify
/// Replaces the unreliable Firecrawl-based services
class PriceValidationService {
    
    private let apifyService: ApifyWalmartService
    
    init(apifyAPIToken: String = AppConfiguration.ApifyAPIToken) {
        self.apifyService = ApifyWalmartService(apiToken: apifyAPIToken)
    }
    
    // MARK: - Public Methods
    
    /// Validates a single receipt item against Walmart website
    func validateItem(_ item: ReceiptItem) async throws -> ApifyPriceValidationResult {
        print("🔍 Validating: \(item.name)")
        
        let apifyResult = try await apifyService.validateReceiptItem(item)
        
        return ApifyPriceValidationResult(
            item: item,
            websitePrice: apifyResult.websitePrice,
            priceDifference: apifyResult.priceDifference,
            percentDifference: apifyResult.percentDifference,
            status: convertStatus(apifyResult.status),
            confidence: convertConfidence(apifyResult.confidence),
            notes: apifyResult.notes
        )
    }
    
    /// Validates multiple items in batch
    func validateItems(_ items: [ReceiptItem]) async throws -> [ApifyPriceValidationResult] {
        var results: [ApifyPriceValidationResult] = []
        
        for (index, item) in items.enumerated() {
            do {
                let result = try await validateItem(item)
                results.append(result)
                
                // Rate limiting
                if index < items.count - 1 {
                    try await Task.sleep(nanoseconds: UInt64(AppConfiguration.validationDelay * 1_000_000_000))
                }
            } catch {
                print("❌ Failed to validate \(item.name): \(error.localizedDescription)")
                
                results.append(ApifyPriceValidationResult(
                    item: item,
                    websitePrice: nil,
                    priceDifference: nil,
                    percentDifference: nil,
                    status: .error,
                    confidence: .none,
                    notes: "Validation failed: \(error.localizedDescription)"
                ))
            }
        }
        
        return results
    }
    
    /// Validates entire receipt
    func validateReceipt(_ receipt: Receipt) async throws -> PriceReceiptValidationSummary {
        let results = try await validateItems(receipt.items)
        
        let flaggedItems = results.filter { result in
            result.status == .possibleOvercharge || 
            result.status == .significantOvercharge
        }
        
        return PriceReceiptValidationSummary(
            receipt: receipt,
            results: results,
            flaggedItems: flaggedItems,
            validationDate: Date()
        )
    }
    
    // MARK: - Private Methods
    
    private func convertStatus(_ apifyStatus: ApifyValidationStatus) -> PriceValidationStatus {
        switch apifyStatus {
        case .exactMatch:
            return .exactMatch
        case .withinTolerance:
            return .withinTolerance
        case .receiptLower:
            return .receiptLower
        case .possibleOvercharge:
            return .possibleOvercharge
        case .significantOvercharge:
            return .significantOvercharge
        case .notFound:
            return .notFound
        }
    }
    
    private func convertConfidence(_ apifyConfidence: ApifyConfidenceLevel) -> PriceConfidenceLevel {
        switch apifyConfidence {
        case .high:
            return .high
        case .medium:
            return .medium
        case .low:
            return .low
        case .none:
            return .none
        }
    }
}

// MARK: - Models

struct ApifyPriceValidationResult {
    let item: ReceiptItem
    let websitePrice: Double?
    let priceDifference: Double?
    let percentDifference: Double?
    let status: PriceValidationStatus
    let confidence: PriceConfidenceLevel
    let notes: String
    
    var shouldFlag: Bool {
        status == .possibleOvercharge || status == .significantOvercharge
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
        switch status {
        case .exactMatch: return "✅"
        case .withinTolerance: return "✓"
        case .receiptLower: return "✓"
        case .possibleOvercharge: return "⚠️"
        case .significantOvercharge: return "🚨"
        case .notFound: return "🔍"
        case .error: return "❌"
        }
    }
}

enum PriceValidationStatus {
    case exactMatch
    case withinTolerance
    case receiptLower
    case possibleOvercharge
    case significantOvercharge
    case notFound
    case error
}

enum PriceConfidenceLevel {
    case high
    case medium
    case low
    case none
}

struct PriceReceiptValidationSummary {
    let receipt: Receipt
    let results: [ApifyPriceValidationResult]
    let flaggedItems: [ApifyPriceValidationResult]
    let validationDate: Date
    
    var totalItems: Int {
        results.count
    }
    
    var successfulValidations: Int {
        results.filter { $0.status != .notFound && $0.status != .error }.count
    }
    
    var exactMatches: Int {
        results.filter { $0.status == .exactMatch }.count
    }
    
    var withinTolerance: Int {
        results.filter { $0.status == .withinTolerance }.count
    }
    
    var possibleOvercharges: Int {
        results.filter { $0.status == .possibleOvercharge }.count
    }
    
    var significantOvercharges: Int {
        results.filter { $0.status == .significantOvercharge }.count
    }
    
    var totalPotentialOvercharge: Double {
        flaggedItems.compactMap { $0.priceDifference }.filter { $0 > 0 }.reduce(0, +)
    }
    
    var overallStatus: OverallStatus {
        if significantOvercharges > 0 {
            return .hasSignificantIssues
        } else if possibleOvercharges > 0 {
            return .hasPossibleIssues
        } else if successfulValidations == totalItems {
            return .allGood
        } else {
            return .needsReview
        }
    }
    
    var summaryText: String {
        """
        Receipt Validation Summary
        
        Total Items: \(totalItems)
        Successfully Validated: \(successfulValidations)
        ✅ Exact Matches: \(exactMatches)
        ✓ Within Tolerance: \(withinTolerance)
        ⚠️ Possible Overcharges: \(possibleOvercharges)
        🚨 Significant Overcharges: \(significantOvercharges)
        
        Potential Overcharge Total: $\(String(format: "%.2f", totalPotentialOvercharge))
        
        Status: \(overallStatus.displayText)
        """
    }
}

enum OverallStatus {
    case allGood
    case hasPossibleIssues
    case hasSignificantIssues
    case needsReview
    
    var displayText: String {
        switch self {
        case .allGood:
            return "✅ All charges appear correct"
        case .hasPossibleIssues:
            return "⚠️ Some items may be overcharged - review recommended"
        case .hasSignificantIssues:
            return "🚨 Significant billing errors detected - contact store"
        case .needsReview:
            return "❓ Manual review needed"
        }
    }
}

// MARK: - Usage Example
/*
 let service = PriceValidationService()
 
 // Validate single item
 let result: ApifyPriceValidationResult = try await service.validateItem(receiptItem)
 print("\(result.statusIcon) \(result.item.name)")
 print("Receipt: $\(result.item.price)")
 if let webPrice = result.websitePrice {
     print("Website: $\(webPrice)")
     print("Difference: \(result.formattedDifference)")
 }
 
 // Validate entire receipt
 let summary: PriceReceiptValidationSummary = try await service.validateReceipt(receipt)
 print(summary.summaryText)
 
 for flaggedItem in summary.flaggedItems {
     print("\n⚠️ FLAGGED: \(flaggedItem.item.name)")
     print("   \(flaggedItem.notes)")
 }
 */
