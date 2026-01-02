//
//  ValidationResultsView.swift
//  ReceiptValidator
//
//  Created by JC Smith on 1/1/26.
//

import SwiftUI

struct ValidationResultsView: View {
    let validationResult: ReceiptValidationResult
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Summary Section
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: validationResult.validationRate > 0.7 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(validationResult.validationRate > 0.7 ? .green : .orange)
                        
                        Text("\(Int(validationResult.validationRate * 100))% Validated")
                            .font(.title2.bold())
                        
                        Text("\(validationResult.validItems.count) of \(validationResult.items.count) items validated")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                
                // Price Comparison Summary
                if validationResult.items.contains(where: { $0.currentOnlinePrice != nil }) {
                    Section("Price Comparison") {
                        let totalPaid = validationResult.items.reduce(0.0) { $0 + $1.item.price }
                        let totalCurrent = validationResult.items.compactMap { $0.currentOnlinePrice }.reduce(0.0, +)
                        let totalDifference = totalPaid - totalCurrent
                        
                        LabeledContent("Total Paid") {
                            Text("$\(totalPaid, specifier: "%.2f")")
                        }
                        LabeledContent("Current Online Total") {
                            Text("$\(totalCurrent, specifier: "%.2f")")
                        }
                        
                        LabeledContent("Difference") {
                            HStack {
                                if totalDifference > 0 {
                                    Image(systemName: "arrow.up")
                                        .foregroundStyle(.red)
                                    Text("$\(abs(totalDifference), specifier: "%.2f")")
                                        .foregroundStyle(.red)
                                        .bold()
                                } else if totalDifference < 0 {
                                    Image(systemName: "arrow.down")
                                        .foregroundStyle(.green)
                                    Text("$\(abs(totalDifference), specifier: "%.2f")")
                                        .foregroundStyle(.green)
                                        .bold()
                                } else {
                                    Text("$0.00")
                                        .foregroundStyle(.blue)
                                        .bold()
                                }
                            }
                        }
                        
                        if totalDifference > 0 {
                            Text("You paid more than current online prices")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if totalDifference < 0 {
                            Text("You saved compared to current online prices!")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }
                
                // Validated Items
                Section("Validated Items (\(validationResult.validItems.count))") {
                    ForEach(validationResult.validItems) { validatedItem in
                        ValidatedItemRow(item: validatedItem)
                    }
                }
                
                // Invalid Items
                if !validationResult.invalidItems.isEmpty {
                    Section("Could Not Validate (\(validationResult.invalidItems.count))") {
                        ForEach(validationResult.invalidItems) { validatedItem in
                            ValidatedItemRow(item: validatedItem)
                        }
                    }
                }
                
                // Suspicious Items
                if !validationResult.suspiciousItems.isEmpty {
                    Section("Low Confidence (\(validationResult.suspiciousItems.count))") {
                        ForEach(validationResult.suspiciousItems) { validatedItem in
                            ValidatedItemRow(item: validatedItem)
                        }
                    }
                }
            }
            .navigationTitle("Validation Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ValidatedItemRow: View {
    let item: ValidatedItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Item name and confidence
            HStack {
                Text(item.item.name)
                    .font(.body)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text("\(Int(item.confidence * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Price information
            HStack(spacing: 16) {
                // Receipt price
                VStack(alignment: .leading, spacing: 2) {
                    Text("Receipt")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("$\(item.item.price, specifier: "%.2f")")
                        .font(.subheadline)
                        .bold()
                }
                
                // Current online price
                if let onlinePrice = item.currentOnlinePrice {
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Online")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("$\(onlinePrice, specifier: "%.2f")")
                            .font(.subheadline)
                            .bold()
                    }
                    
                    // Price difference badge
                    if let diff = item.priceDifference {
                        Spacer()
                        
                        HStack(spacing: 2) {
                            Image(systemName: diff > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .foregroundStyle(diff > 0 ? .red : .green)
                            Text("$\(abs(diff), specifier: "%.2f")")
                                .font(.caption.bold())
                                .foregroundStyle(diff > 0 ? .red : .green)
                        }
                    }
                }
            }
            
            // Validation message
            if let message = item.validationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Product URL link
            if let urlString = item.productURL, let url = URL(string: urlString) {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "link")
                        Text("View Product Online")
                    }
                    .font(.caption)
                }
            }
            
            // Stock status
            if let inStock = item.inStock {
                HStack {
                    Image(systemName: inStock ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(inStock ? .green : .red)
                    Text(inStock ? "In Stock" : "Out of Stock")
                        .font(.caption2)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusColor: Color {
        if item.isValid && item.confidence > 0.7 {
            return .green
        } else if item.confidence > 0.5 {
            return .orange
        } else {
            return .red
        }
    }
}

#Preview {
    let sampleItems = [
        ValidatedItem(
            item: ScannedItem(name: "Milk", price: 3.99),
            isValid: true,
            confidence: 0.85,
            validationMessage: "You paid $0.50 more than current online price",
            currentOnlinePrice: 3.49,
            priceDifference: 0.50,
            productURL: "https://www.walmart.com/ip/milk",
            inStock: true
        ),
        ValidatedItem(
            item: ScannedItem(name: "Bread", price: 2.49),
            isValid: true,
            confidence: 0.92,
            validationMessage: "Price matches current online price",
            currentOnlinePrice: 2.49,
            priceDifference: 0.0,
            productURL: "https://www.walmart.com/ip/bread",
            inStock: true
        ),
        ValidatedItem(
            item: ScannedItem(name: "Eggs", price: 4.99),
            isValid: false,
            confidence: 0.3,
            validationMessage: "Product not found on Walmart.com",
            currentOnlinePrice: nil,
            priceDifference: nil
        )
    ]
    
    let result = ReceiptValidationResult(
        storeName: "Walmart",
        items: sampleItems,
        totalAmount: 11.47,
        rawText: "Sample receipt"
    )
    
    return ValidationResultsView(validationResult: result)
}
