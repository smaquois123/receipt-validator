//
//  ManualPriceVerificationView.swift
//  ReceiptValidator
//
//  Created by JC Smith on 1/3/26.
//

import SwiftUI

/// Manual verification view for when automatic validation isn't possible
/// User searches website themselves and enters the current price
struct ManualPriceVerificationView: View {
    let item: ReceiptItem
    let retailer: String
    
    @State private var websitePrice: String = ""
    @State private var verificationResult: VerificationResult?
    @State private var notes: String = ""
    @Environment(\.dismiss) private var dismiss
    
    private var websitePriceDouble: Double? {
        Double(websitePrice)
    }
    
    private var priceDifference: Double? {
        guard let webPrice = websitePriceDouble else { return nil }
        return item.price - webPrice
    }
    
    private var percentDifference: Double? {
        guard let webPrice = websitePriceDouble, webPrice > 0 else { return nil }
        return ((item.price - webPrice) / webPrice) * 100
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Item Info Section
                Section("Receipt Item") {
                    LabeledContent("Name", value: item.name)
                    LabeledContent("Receipt Price") {
                        Text("$\(item.price, specifier: "%.2f")")
                            .fontWeight(.semibold)
                    }
                    
                    if let upc = item.upc {
                        LabeledContent("UPC") {
                            Text(upc)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }
                
                // Search Instructions
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Manual Verification Needed", systemImage: "info.circle")
                            .font(.headline)
                        
                        Text("Automatic validation requires a UPC lookup API. For now, please verify the price manually:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1. Click the link below to search \(retailer)")
                            Text("2. Find the exact product (match UPC if available)")
                            Text("3. Note the current website price")
                            Text("4. Enter it below to compare")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Instructions")
                }
                
                // Search Links
                Section("Search \(retailer) Website") {
                    if let upc = item.upc {
                        Link(destination: searchURL(upc: upc, productName: nil)) {
                            Label("Search by UPC: \(upc)", systemImage: "barcode")
                        }
                    }
                    
                    Link(destination: searchURL(upc: nil, productName: item.name)) {
                        Label("Search by Name: \(item.name)", systemImage: "magnifyingglass")
                    }
                }
                
                // Price Entry
                Section {
                    HStack {
                        Text("Website Price:")
                        Spacer()
                        Text("$")
                        TextField("0.00", text: $websitePrice)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    // Show comparison if price entered
                    if websitePriceDouble != nil {
                        LabeledContent("Receipt Price") {
                            Text("$\(item.price, specifier: "%.2f")")
                        }
                        
                        if let diff = priceDifference {
                            LabeledContent("Difference") {
                                Text(formatDifference(diff))
                                    .foregroundStyle(differenceColor(diff))
                                    .fontWeight(.semibold)
                            }
                        }
                        
                        if let percent = percentDifference {
                            LabeledContent("Percent") {
                                Text(formatPercent(percent))
                                    .foregroundStyle(differenceColor(priceDifference ?? 0))
                            }
                        }
                    }
                } header: {
                    Text("Price Comparison")
                }
                
                // Notes
                Section("Notes (Optional)") {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                }
                
                // Save Button
                Section {
                    Button {
                        saveVerification()
                    } label: {
                        Text("Save Verification")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                    }
                    .disabled(websitePrice.isEmpty)
                }
            }
            .navigationTitle("Verify Price")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func searchURL(upc: String?, productName: String?) -> URL {
        let baseURL: String
        let query: String
        
        switch retailer.lowercased() {
        case let r where r.contains("walmart"):
            baseURL = "https://www.walmart.com/search"
            query = upc ?? productName ?? ""
            
        case let r where r.contains("target"):
            baseURL = "https://www.target.com/s"
            query = upc ?? productName ?? ""
            return URL(string: "\(baseURL)?searchTerm=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
            
        case let r where r.contains("amazon"):
            baseURL = "https://www.amazon.com/s"
            query = upc ?? productName ?? ""
            return URL(string: "\(baseURL)?k=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
            
        default:
            // Generic Google search
            query = "\(retailer) \(upc ?? productName ?? "")"
            return URL(string: "https://www.google.com/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
        }
        
        return URL(string: "\(baseURL)?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
    }
    
    private func formatDifference(_ diff: Double) -> String {
        let prefix = diff > 0 ? "+" : ""
        return "\(prefix)$\(abs(diff), default: "%.2f")"
    }
    
    private func formatPercent(_ percent: Double) -> String {
        let prefix = percent > 0 ? "+" : ""
        return "\(prefix)\(abs(percent), default: "%.1f")%"
    }
    
    private func differenceColor(_ diff: Double) -> Color {
        if diff > 0 {
            return .red  // Overcharged
        } else if diff < 0 {
            return .green  // Undercharged
        } else {
            return .primary
        }
    }
    
    private func saveVerification() {
        guard let webPrice = websitePriceDouble else { return }
        
        // Update the item with verified price
        item.currentWebPrice = webPrice
        item.priceComparisonDate = Date()
        
        // You could also save verification details to a separate model if needed
        let result = VerificationResult(
            item: item,
            receiptPrice: item.price,
            websitePrice: webPrice,
            difference: priceDifference,
            percentDifference: percentDifference,
            verifiedManually: true,
            verificationDate: Date(),
            notes: notes.isEmpty ? nil : notes
        )
        
        verificationResult = result
        
        // Show result briefly then dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }
}

// MARK: - Models

struct VerificationResult {
    let item: ReceiptItem
    let receiptPrice: Double
    let websitePrice: Double
    let difference: Double?
    let percentDifference: Double?
    let verifiedManually: Bool
    let verificationDate: Date
    let notes: String?
    
    var status: VerificationStatus {
        guard let percent = percentDifference else { return .uncertain }
        
        let tolerance = AppConfiguration.priceTolerancePercentage * 100
        
        if abs(percent) <= 1.0 {
            return .exactMatch
        } else if abs(percent) <= tolerance {
            return .withinTolerance
        } else if percent > tolerance {
            return .possibleOvercharge
        } else {
            return .receiptLower
        }
    }
    
    var statusText: String {
        switch status {
        case .exactMatch:
            return "✅ Prices match"
        case .withinTolerance:
            return "✓ Within normal range"
        case .possibleOvercharge:
            return "⚠️ Possible overcharge - consider contacting store"
        case .receiptLower:
            return "✓ You paid less than website price"
        case .uncertain:
            return "Unable to determine"
        }
    }
}

enum VerificationStatus {
    case exactMatch
    case withinTolerance
    case possibleOvercharge
    case receiptLower
    case uncertain
}

// MARK: - Preview

#Preview {
    ManualPriceVerificationView(
        item: ReceiptItem(
            name: "Seagrams Ginger Ale",
            price: 1.99,
            upc: "012345678912"
        ),
        retailer: "Walmart"
    )
}

// MARK: - Integration Example
/*
 Use this view for items that can't be auto-validated:
 
 // In your receipt detail view:
 ForEach(receipt.items) { item in
     HStack {
         VStack(alignment: .leading) {
             Text(item.name)
             if let webPrice = item.currentWebPrice {
                 Text("Website: $\(webPrice, specifier: "%.2f")")
                     .font(.caption)
                     .foregroundStyle(.secondary)
             }
         }
         
         Spacer()
         
         if item.currentWebPrice == nil {
             Button("Verify Price") {
                 showManualVerification(for: item)
             }
         } else {
             Image(systemName: "checkmark.circle.fill")
                 .foregroundStyle(.green)
         }
     }
 }
 .sheet(isPresented: $showingManualVerification) {
     ManualPriceVerificationView(
         item: selectedItem,
         retailer: receipt.storeName ?? "Retailer"
     )
 }
 */
