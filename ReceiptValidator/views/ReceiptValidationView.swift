//
//  ReceiptValidationView.swift
//  ReceiptValidator
//
//  Created by JC Smith on 1/2/26.
//

import SwiftUI

/// View for validating receipt charges against retailer website prices
/// Shows flagged items that may be overcharges or billing errors
struct ReceiptValidationView: View {
    let receipt: Receipt
    
    @State private var validationSummary: PriceReceiptValidationSummary?
    @State private var isValidating = false
    @State private var error: Error?
    @State private var showingAllItems = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                receiptHeader
                
                if isValidating {
                    validatingView
                } else if let summary = validationSummary {
                    validationResults(summary)
                } else {
                    validateButton
                }
                
                if let error = error {
                    errorView(error)
                }
            }
            .padding()
        }
        .navigationTitle("Validate Charges")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Subviews
    
    private var receiptHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let storeName = receipt.storeName {
                Text(storeName)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Text(receipt.timestamp, style: .date)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if let total = receipt.totalAmount {
                Text("Receipt Total: $\(total, specifier: "%.2f")")
                    .font(.headline)
            }
            
            Text("\(receipt.items.count) items")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var validateButton: some View {
        VStack(spacing: 12) {
            Button {
                validateReceipt()
            } label: {
                Label("Validate Charges", systemImage: "checkmark.shield")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            
            Text("Compare receipt prices with \(receipt.storeName ?? "retailer") website to detect overcharges")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var validatingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Validating charges...")
                .font(.headline)
            
            Text("Checking prices against \(receipt.storeName ?? "retailer") website")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
    
    private func validationResults(_ summary: PriceReceiptValidationSummary) -> some View {
        VStack(spacing: 20) {
            // Overall status
            overallStatusCard(summary)
            
            // Flagged items (if any)
            if !summary.flaggedItems.isEmpty {
                flaggedItemsSection(summary)
            }
            
            // All items toggle
            allItemsSection(summary)
        }
    }
    
    private func overallStatusCard(_ summary: PriceReceiptValidationSummary) -> some View {
        VStack(spacing: 12) {
            // Status icon and text
            HStack {
                Image(systemName: statusIcon(for: summary.overallStatus))
                    .font(.title)
                    .foregroundStyle(statusColor(for: summary.overallStatus))
                
                Text(summary.overallStatus.displayText)
                    .font(.headline)
            }
            
            Divider()
            
            // Stats
            VStack(spacing: 8) {
                HStack {
                    Text("Items Validated:")
                    Spacer()
                    Text("\(summary.successfulValidations)")
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Within Normal Range:")
                    Spacer()
                    Text("\(summary.withinTolerance)")
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                }
                
                if summary.possibleOvercharges > 0 {
                    HStack {
                        Text("Possible Overcharges:")
                        Spacer()
                        Text("\(summary.possibleOvercharges)")
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                    }
                }
                
                if summary.significantOvercharges > 0 {
                    HStack {
                        Text("Significant Errors:")
                        Spacer()
                        Text("\(summary.significantOvercharges)")
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                    }
                }
                
                if summary.totalPotentialOvercharge > 0 {
                    Divider()
                    HStack {
                        Text("Potential Overcharge:")
                        Spacer()
                        Text("$\(summary.totalPotentialOvercharge, specifier: "%.2f")")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.red)
                    }
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func flaggedItemsSection(_ summary: PriceReceiptValidationSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("⚠️ Flagged Items")
                .font(.title3)
                .fontWeight(.bold)
            
            ForEach(summary.flaggedItems, id: \.item.id) { result in
                validationItemCard(result, showAllDetails: true)
            }
        }
    }
    
    private func allItemsSection(_ summary: PriceReceiptValidationSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                showingAllItems.toggle()
            } label: {
                HStack {
                    Text("All Items (\(summary.totalItems))")
                        .font(.headline)
                    Spacer()
                    Image(systemName: showingAllItems ? "chevron.up" : "chevron.down")
                }
            }
            .foregroundColor(.primary)
            
            if showingAllItems {
                ForEach(summary.results, id: \.item.id) { result in
                    validationItemCard(result, showAllDetails: false)
                }
            }
        }
    }
    
    private func validationItemCard(_ result: ApifyPriceValidationResult, showAllDetails: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Item name and status
            HStack {
                Text(result.statusIcon)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.item.name)
                        .font(.headline)
                    
                    if let upc = result.item.upc {
                        Text("UPC: \(upc)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Price comparison
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Receipt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("$\(result.item.price, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                if let websitePrice = result.websitePrice {
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Website")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("$\(websitePrice, specifier: "%.2f")")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Difference")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(result.formattedDifference)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(differenceColor(result.priceDifference))
                    }
                }
            }
            
            // Notes (for flagged items or when showing all details)
            if showAllDetails || result.shouldFlag {
                Text(result.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(cardBackgroundColor(for: result.status))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor(for: result.status), lineWidth: result.shouldFlag ? 2 : 0)
        )
    }
    
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundStyle(.red)
            
            Text("Validation Error")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                self.error = nil
                validateReceipt()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    
    private func validateReceipt() {
        isValidating = true
        error = nil
        
        Task {
            do {
                let service = PriceValidationService()
                let summary = try await service.validateReceipt(receipt)
                
                await MainActor.run {
                    self.validationSummary = summary
                    self.isValidating = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isValidating = false
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func statusIcon(for status: OverallStatus) -> String {
        switch status {
        case .allGood: return "checkmark.circle.fill"
        case .hasPossibleIssues: return "exclamationmark.triangle.fill"
        case .hasSignificantIssues: return "exclamationmark.circle.fill"
        case .needsReview: return "questionmark.circle.fill"
        }
    }
    
    private func statusColor(for status: OverallStatus) -> Color {
        switch status {
        case .allGood: return .green
        case .hasPossibleIssues: return .orange
        case .hasSignificantIssues: return .red
        case .needsReview: return .yellow
        }
    }
    
    private func differenceColor(_ difference: Double?) -> Color {
        guard let diff = difference else { return .secondary }
        if diff > 0 { return .red }
        if diff < 0 { return .green }
        return .secondary
    }
    
    private func cardBackgroundColor(for status: PriceValidationStatus) -> Color {
        switch status {
        case .significantOvercharge:
            return Color.red.opacity(0.1)
        case .possibleOvercharge:
            return Color.orange.opacity(0.1)
        default:
            return Color(.systemGray6)
        }
    }
    
    private func borderColor(for status: PriceValidationStatus) -> Color {
        switch status {
        case .significantOvercharge:
            return .red
        case .possibleOvercharge:
            return .orange
        default:
            return .clear
        }
    }
}

// MARK: - Preview

#Preview {
    let receipt = Receipt(
        storeName: "Walmart",
        totalAmount: 45.67
    )
    receipt.items = [
        ReceiptItem(name: "Coca-Cola 12pk", price: 6.99, upc: "012000161292"),
        ReceiptItem(name: "Tide Detergent", price: 12.99, upc: "037000740575"),
        ReceiptItem(name: "Wonder Bread", price: 2.49)
    ]
    
    return NavigationStack {
        ReceiptValidationView(receipt: receipt)
    }
}
