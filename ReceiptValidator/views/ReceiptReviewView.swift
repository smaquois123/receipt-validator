//
//  ReceiptReviewView.swift
//  ReceiptValidator
//
//  Created by JC Smith on 12/23/25.
//

import SwiftUI
import SwiftData

struct ReceiptReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let scannedData: ScannedReceiptData
    let image: UIImage?
    let retailer: RetailerType
    
    @State private var storeName: String
    @State private var items: [EditableItem]
    @State private var totalAmount: String
    @State private var showRawText = false
    @State private var isSaving = false
    @State private var showValidation = false
    @State private var validationResult: ValidationSummary?
    
    @StateObject private var validator = ReceiptValidatorService()
    
    init(scannedData: ScannedReceiptData, image: UIImage?, retailer: RetailerType) {
        self.scannedData = scannedData
        self.image = image
        self.retailer = retailer
        
        _storeName = State(initialValue: scannedData.storeName ?? "")
        _items = State(initialValue: scannedData.items.map { EditableItem(name: $0.name, price: $0.price) })
        _totalAmount = State(initialValue: scannedData.totalAmount.map { String(format: "%.2f", $0) } ?? "")
    }
    
    var body: some View {
        Form {
            Section("Receipt Details") {
                TextField("Store Name", text: $storeName)
                
                HStack {
                    Text("Total")
                    Spacer()
                    TextField("0.00", text: $totalAmount)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
            }
            
            Section("Items (\(items.count))") {
                ForEach($items) { $item in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Item name", text: $item.name)
                            .font(.body)
                        
                        HStack {
                            Text("Price:")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                            
                            TextField("0.00", value: $item.price, format: .number.precision(.fractionLength(2)))
                                .keyboardType(.decimalPad)
                                .frame(width: 80)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    items.remove(atOffsets: indexSet)
                }
                .onMove { from, to in
                    items.move(fromOffsets: from, toOffset: to)
                }
                
                Button {
                    items.append(EditableItem(name: "", price: 0.0))
                } label: {
                    Label("Add Item", systemImage: "plus.circle.fill")
                }
            }
            
            // Validation section
            Section {
                Button {
                    Task {
                        await validatePrices()
                    }
                } label: {
                    HStack {
                        if validator.isValidating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.shield.fill")
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Validate Prices")
                                .font(.body)
                            Text("Compare receipt prices with current online prices")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(validator.isValidating || items.isEmpty)
                
                if validator.isValidating {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: validator.validationProgress)
                        Text("Checking prices... \(Int(validator.validationProgress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Price Validation")
            } footer: {
                Text("Uses FireCrawl to check current online prices. This may take a moment.")
                    .font(.caption2)
            }
            
            Section {
                Button {
                    showRawText.toggle()
                } label: {
                    Label(
                        showRawText ? "Hide Raw Text" : "Show Raw Text",
                        systemImage: showRawText ? "eye.slash" : "eye"
                    )
                }
                
                if showRawText {
                    Text(scannedData.rawText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle("Review Receipt")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button("Save") {
                    saveReceipt()
                }
                .disabled(isSaving || items.isEmpty)
            }
            
            ToolbarItem(placement: .secondaryAction) {
                EditButton()
            }
        }
        .sheet(isPresented: $showValidation) {
            if let result = validationResult {
                ValidationResultsSheet(validationSummary: result)
            }
        }
    }
    
    private func validatePrices() async {
        // Convert EditableItems back to ScannedItems
        let scannedItems = items.map { ScannedItem(name: $0.name, price: $0.price) }
        let dataToValidate = ScannedReceiptData(
            storeName: storeName,
            items: scannedItems,
            totalAmount: Double(totalAmount),
            rawText: scannedData.rawText
        )
        
        do {
            let result = try await validator.validateReceipt(dataToValidate, retailer: retailer)
            validationResult = result
            showValidation = true
        } catch {
            print("Validation failed: \(error)")
        }
    }
    
    private func saveReceipt() {
        isSaving = true
        
        let receipt = Receipt(
            timestamp: Date(),
            storeName: storeName.isEmpty ? nil : storeName,
            totalAmount: Double(totalAmount),
            imageData: image?.jpegData(compressionQuality: 0.8)
        )
        
        // Create receipt items
        for item in items where !item.name.isEmpty {
            let receiptItem = ReceiptItem(
                name: item.name,
                price: item.price
            )
            receiptItem.receipt = receipt
            receipt.items.append(receiptItem)
        }
        
        modelContext.insert(receipt)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save receipt: \(error)")
            isSaving = false
        }
    }
}

struct EditableItem: Identifiable {
    let id = UUID()
    var name: String
    var price: Double
}

// MARK: - Validation Results View

struct ValidationResultsSheet: View {
    let validationSummary: ValidationSummary
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Summary Section
                Section {
                    VStack(spacing: 12) {
                        let successRate = Double(validationSummary.successfulValidations) / Double(validationSummary.items.count)
                        
                        Image(systemName: successRate > 0.7 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(successRate > 0.7 ? .green : .orange)
                        
                        Text("\(Int(successRate * 100))% Validated")
                            .font(.title2.bold())
                        
                        Text("\(validationSummary.successfulValidations) of \(validationSummary.items.count) items validated")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                
                // Price Comparison Summary
                if validationSummary.items.contains(where: { $0.priceValidationResult.onlinePrice != nil }) {
                    Section("Price Comparison") {
                        let totalPaid = validationSummary.items.reduce(0.0) { $0 + $1.scannedItem.price }
                        let totalCurrent = validationSummary.items.compactMap { $0.priceValidationResult.onlinePrice }.reduce(0.0, +)
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
                
                // Flagged Items
                if !validationSummary.flaggedItems.isEmpty {
                    Section("⚠️ Price Alerts (\(validationSummary.flaggedItems.count))") {
                        ForEach(validationSummary.flaggedItems) { result in
                            ItemValidationRow(result: result, highlighted: true)
                        }
                    }
                }
                
                // All Items
                Section("All Items (\(validationSummary.items.count))") {
                    ForEach(validationSummary.items) { result in
                        ItemValidationRow(result: result, highlighted: false)
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

struct ItemValidationRow: View {
    let result: ItemValidationResult
    let highlighted: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Item name and validation method
            HStack {
                Text(result.scannedItem.name)
                    .font(.body)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(result.priceValidationResult.validationMethod.icon)
                        .font(.caption)
                    
                    if result.priceValidationResult.onlinePrice != nil {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                    } else {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                    }
                }
            }
            
            // Price information
            HStack(spacing: 16) {
                // Receipt price
                VStack(alignment: .leading, spacing: 2) {
                    Text("Receipt")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("$\(result.scannedItem.price, specifier: "%.2f")")
                        .font(.subheadline)
                        .bold()
                }
                
                // Current online price
                if let onlinePrice = result.priceValidationResult.onlinePrice {
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
                    if let diff = result.priceValidationResult.priceDifference {
                        Spacer()
                        
                        HStack(spacing: 2) {
                            Image(systemName: diff > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .foregroundStyle(diff > 0 ? .red : .green)
                            Text(result.priceValidationResult.formattedDifference)
                                .font(.caption.bold())
                                .foregroundStyle(diff > 0 ? .red : .green)
                        }
                    }
                }
            }
            
            // Error message if validation failed
            if let error = result.priceValidationResult.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Product URL link
            if let urlString = result.priceValidationResult.productURL, let url = URL(string: urlString) {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "link")
                        Text("View Product Online")
                    }
                    .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
        .if(highlighted) { view in
            view.listRowBackground(Color.orange.opacity(0.1))
        }
    }
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

#Preview {
    NavigationStack {
        ReceiptReviewView(
            scannedData: ScannedReceiptData(
                storeName: "Walmart",
                items: [
                    ScannedItem(name: "Milk", price: 3.99),
                    ScannedItem(name: "Bread", price: 2.49)
                ],
                totalAmount: 6.48,
                rawText: "Sample receipt text"
            ),
            image: nil,
            retailer: .walmart
        )
    }
    .modelContainer(for: Receipt.self, inMemory: true)
}

