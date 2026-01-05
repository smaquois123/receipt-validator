# PriceValidationService - Quick Reference

## Overview
`PriceValidationService` is a simplified, reliable service for validating receipt prices using only Apify (no Firecrawl). It replaces all the old Firecrawl-based validation services.

## Key Types

### PriceValidationResult
Contains validation result for a single item:
- `item: ReceiptItem` - The validated item
- `websitePrice: Double?` - Current price on website
- `priceDifference: Double?` - Receipt price - website price
- `percentDifference: Double?` - Percent difference
- `status: PriceValidationStatus` - Validation status
- `confidence: PriceConfidenceLevel` - Confidence level
- `notes: String` - Human-readable notes
- `shouldFlag: Bool` - Whether to flag this item
- `formattedDifference: String` - Formatted price difference
- `formattedPercentDifference: String` - Formatted percent difference
- `statusIcon: String` - Emoji icon for status

### PriceValidationStatus (enum)
- `.exactMatch` - Prices match (✅)
- `.withinTolerance` - Within acceptable range (✓)
- `.receiptLower` - Paid less than website (✓)
- `.possibleOvercharge` - May be overcharged (⚠️)
- `.significantOvercharge` - Likely overcharged (🚨)
- `.notFound` - Product not found (🔍)
- `.error` - Validation failed (❌)

### PriceConfidenceLevel (enum)
- `.high` - UPC matched, high confidence
- `.medium` - Moderate confidence
- `.low` - Low confidence (name match only)
- `.none` - No confidence (not found)

### PriceReceiptValidationSummary
Contains summary for entire receipt:
- `receipt: Receipt` - The validated receipt
- `results: [PriceValidationResult]` - All validation results
- `flaggedItems: [PriceValidationResult]` - Items flagged as overcharged
- `validationDate: Date` - When validation occurred
- `totalItems: Int` - Total items validated
- `successfulValidations: Int` - Successfully validated items
- `exactMatches: Int` - Items with exact price match
- `withinTolerance: Int` - Items within tolerance
- `possibleOvercharges: Int` - Items possibly overcharged
- `significantOvercharges: Int` - Items significantly overcharged
- `totalPotentialOvercharge: Double` - Total potential overcharge amount
- `overallStatus: OverallStatus` - Overall receipt status
- `summaryText: String` - Human-readable summary

## Usage Examples

### Validate Single Item
```swift
let service = PriceValidationService()

do {
    let result = try await service.validateItem(receiptItem)
    
    print("\(result.statusIcon) \(result.item.name)")
    print("Receipt: $\(result.item.price)")
    
    if let webPrice = result.websitePrice {
        print("Website: $\(webPrice)")
        print("Difference: \(result.formattedDifference) (\(result.formattedPercentDifference))")
    }
    
    if result.shouldFlag {
        print("⚠️ \(result.notes)")
    }
} catch {
    print("Error: \(error.localizedDescription)")
}
```

### Validate Multiple Items
```swift
let service = PriceValidationService()

do {
    let results = try await service.validateItems(receipt.items)
    
    // Print summary
    let flagged = results.filter { $0.shouldFlag }
    print("Validated: \(results.count) items")
    print("Flagged: \(flagged.count) items")
    
    // Show flagged items
    for result in flagged {
        print("\n⚠️ \(result.item.name)")
        print("   Receipt: $\(result.item.price)")
        print("   Website: $\(result.websitePrice ?? 0)")
        print("   \(result.notes)")
    }
} catch {
    print("Error: \(error.localizedDescription)")
}
```

### Validate Entire Receipt
```swift
let service = PriceValidationService()

do {
    let summary = try await service.validateReceipt(receipt)
    
    // Print summary
    print(summary.summaryText)
    
    // Check overall status
    switch summary.overallStatus {
    case .allGood:
        print("✅ All prices look good!")
    case .hasPossibleIssues:
        print("⚠️ Review flagged items")
    case .hasSignificantIssues:
        print("🚨 Contact store about overcharges!")
    case .needsReview:
        print("❓ Manual review recommended")
    }
    
    // Show potential overcharge
    if summary.totalPotentialOvercharge > 0 {
        print("Total potential overcharge: $\(String(format: "%.2f", summary.totalPotentialOvercharge))")
    }
    
    // List flagged items
    for flagged in summary.flaggedItems {
        print("\n⚠️ FLAGGED: \(flagged.item.name)")
        print("   \(flagged.notes)")
        print("   Receipt: $\(flagged.item.price)")
        print("   Website: $\(flagged.websitePrice ?? 0)")
        print("   Difference: \(flagged.formattedDifference)")
    }
} catch {
    print("Error: \(error.localizedDescription)")
}
```

## SwiftUI Integration

### Basic View
```swift
struct ReceiptValidationView: View {
    let receipt: Receipt
    @State private var summary: PriceReceiptValidationSummary?
    @State private var isValidating = false
    @State private var error: Error?
    
    var body: some View {
        List {
            if let summary {
                ValidationSummarySection(summary: summary)
                FlaggedItemsSection(items: summary.flaggedItems)
            }
            
            ItemsSection(receipt: receipt)
        }
        .toolbar {
            Button(isValidating ? "Validating..." : "Validate") {
                Task { await validate() }
            }
            .disabled(isValidating)
        }
        .alert("Validation Error", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: {
            if let error {
                Text(error.localizedDescription)
            }
        }
    }
    
    private func validate() async {
        isValidating = true
        defer { isValidating = false }
        
        do {
            let service = PriceValidationService()
            summary = try await service.validateReceipt(receipt)
        } catch {
            self.error = error
        }
    }
}
```

### Validation Summary Section
```swift
struct ValidationSummarySection: View {
    let summary: PriceReceiptValidationSummary
    
    var body: some View {
        Section("Summary") {
            LabeledContent("Status") {
                Text(summary.overallStatus.displayText)
                    .foregroundStyle(statusColor)
            }
            
            LabeledContent("Validated") {
                Text("\(summary.successfulValidations)/\(summary.totalItems)")
            }
            
            if summary.totalPotentialOvercharge > 0 {
                LabeledContent("Potential Overcharge") {
                    Text("$\(summary.totalPotentialOvercharge, specifier: "%.2f")")
                        .foregroundStyle(.red)
                        .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var statusColor: Color {
        switch summary.overallStatus {
        case .allGood: .green
        case .hasPossibleIssues: .orange
        case .hasSignificantIssues: .red
        case .needsReview: .yellow
        }
    }
}
```

### Flagged Items Section
```swift
struct FlaggedItemsSection: View {
    let items: [PriceValidationResult]
    
    var body: some View {
        if !items.isEmpty {
            Section("⚠️ Flagged Items") {
                ForEach(items, id: \.item.id) { result in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(result.statusIcon)
                            Text(result.item.name)
                                .font(.headline)
                        }
                        
                        HStack {
                            Text("Receipt:")
                            Text("$\(result.item.price, specifier: "%.2f")")
                                .foregroundStyle(.red)
                        }
                        .font(.subheadline)
                        
                        if let webPrice = result.websitePrice {
                            HStack {
                                Text("Website:")
                                Text("$\(webPrice, specifier: "%.2f")")
                                    .foregroundStyle(.green)
                            }
                            .font(.subheadline)
                        }
                        
                        Text(result.notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
```

## Configuration

Make sure Apify is configured:
```swift
// Check if configured
if AppConfiguration.isApifyConfigured {
    print("✅ Ready to validate")
} else {
    print("❌ Configure Apify API token")
    print(AppConfiguration.configurationMessage)
}
```

## Error Handling

The service throws errors when validation fails. Always wrap in do-catch:
```swift
do {
    let result = try await service.validateItem(item)
    // Handle success
} catch let error as ApifyError {
    switch error {
    case .invalidURL:
        print("Invalid URL")
    case .scraperStartFailed:
        print("Failed to start scraper")
    case .scraperFailed(let status):
        print("Scraper failed: \(status)")
    case .timeout:
        print("Request timed out")
    case .noResults:
        print("No results found")
    default:
        print("Apify error: \(error.localizedDescription)")
    }
} catch {
    print("Validation error: \(error.localizedDescription)")
}
```

## Rate Limiting

The service automatically adds delays between requests to avoid rate limiting:
- Configured via `AppConfiguration.validationDelay` (default: 1.0 seconds)
- Applied automatically in batch operations
- No delay needed for single validations

## Tips

1. **Always use UPC when available** - Much more accurate than name matching
2. **Check confidence level** - High confidence means UPC matched
3. **Flag items require attention** - Use `shouldFlag` to identify problem items
4. **Cache results** - Store validation results to avoid redundant API calls
5. **Handle errors gracefully** - Network issues are common, always have fallback UI

## Comparison to Old Services

| Feature | Old (Firecrawl) | New (Apify) |
|---------|----------------|-------------|
| UPC Search | ❌ No | ✅ Yes |
| Reliability | ⚠️ Poor | ✅ Good |
| Error Handling | ❌ Vague | ✅ Clear |
| Cost | 💰 Variable | 💰 Free tier $5/mo |
| Complexity | 😵 High | 😊 Simple |
| Type Safety | ⚠️ Conflicts | ✅ Clean |

## See Also

- `ApifyWalmartService.swift` - Underlying Apify service
- `ManualPriceVerificationView.swift` - Manual fallback for items that can't be validated
- `AppConfiguration.swift` - API key configuration
- `FIRECRAWL_REMOVAL.md` - Migration guide from old services
