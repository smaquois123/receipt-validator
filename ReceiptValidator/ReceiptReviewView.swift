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
    
    @State private var storeName: String
    @State private var items: [EditableItem]
    @State private var totalAmount: String
    @State private var showRawText = false
    @State private var isSaving = false
    
    init(scannedData: ScannedReceiptData, image: UIImage?) {
        self.scannedData = scannedData
        self.image = image
        
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
            image: nil
        )
    }
    .modelContainer(for: Receipt.self, inMemory: true)
}
