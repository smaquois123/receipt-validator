//
//  ReceiptDetailView.swift
//  ReceiptValidator
//
//  Created by JC Smith on 12/23/25.
//

import SwiftUI
import SwiftData

struct ReceiptDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var receipt: Receipt
    
    @StateObject private var priceChecker = PriceComparisonService()
    @State private var showingImage = false
    
    var body: some View {
        List {
            // Receipt info section
            Section {
                if let imageData = receipt.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Button {
                        showingImage = true
                    } label: {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                
                LabeledContent("Store", value: receipt.storeName ?? "Unknown")
                LabeledContent("Date", value: receipt.timestamp, format: .dateTime)
                
                if let total = receipt.totalAmount {
                    LabeledContent("Total", value: "$\(total, default: "%.2f")")
                }
            }
            
            // Items section
            Section {
                ForEach(receipt.items) { item in
                    ReceiptItemRowView(item: item)
                }
            } header: {
                HStack {
                    Text("Items")
                    Spacer()
                    Button {
                        Task {
                            await checkAllPrices()
                        }
                    } label: {
                        Label("Check Prices", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .disabled(priceChecker.isChecking)
                }
            } footer: {
                if priceChecker.isChecking {
                    HStack {
                        ProgressView()
                        Text("Checking prices...")
                            .font(.caption)
                    }
                }
            }
            
            // Summary section
            if receipt.items.contains(where: { $0.currentWebPrice != nil }) {
                Section("Price Comparison Summary") {
                    let itemsWithPrices = receipt.items.filter { $0.currentWebPrice != nil }
                    let totalSavings = itemsWithPrices.reduce(0.0) { $0 + ($1.priceDifference ?? 0) }
                    
                    LabeledContent("Items Checked", value: "\(itemsWithPrices.count) of \(receipt.items.count)")
                    
                    LabeledContent("Total Difference") {
                        Text("$\(abs(totalSavings), specifier: "%.2f")")
                            .foregroundStyle(totalSavings > 0 ? .red : .green)
                            .bold()
                    }
                    
                    if totalSavings > 0 {
                        Text("You paid $\(totalSavings, specifier: "%.2f") more than current online prices")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if totalSavings < 0 {
                        Text("You saved $\(abs(totalSavings), specifier: "%.2f") compared to current online prices!")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .navigationTitle("Receipt Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingImage) {
            if let imageData = receipt.imageData,
               let uiImage = UIImage(data: imageData) {
                ReceiptImageViewer(image: uiImage)
            }
        }
    }
    
    private func checkAllPrices() async {
        guard let storeName = receipt.storeName else { return }
        
        for item in receipt.items {
            do {
                let webPrice = try await priceChecker.checkPrice(
                    itemName: item.name,
                    storeName: storeName
                )
                
                await MainActor.run {
                    item.currentWebPrice = webPrice
                    item.priceComparisonDate = Date()
                }
            } catch {
                print("Failed to check price for \(item.name): \(error)")
            }
        }
        
        try? modelContext.save()
    }
}

struct ReceiptItemRowView: View {
    let item: ReceiptItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.name)
                .font(.body)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Receipt Price")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("$\(item.price, specifier: "%.2f")")
                        .font(.subheadline.bold())
                }
                
                if let webPrice = item.currentWebPrice {
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Current Online")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("$\(webPrice, specifier: "%.2f")")
                            .font(.subheadline.bold())
                    }
                    
                    if let difference = item.priceDifference {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Difference")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("$\(abs(difference), specifier: "%.2f")")
                                .font(.subheadline.bold())
                                .foregroundStyle(difference > 0 ? .red : .green)
                        }
                    }
                }
            }
            
            if let compareDate = item.priceComparisonDate {
                Text("Checked \(compareDate, format: .relative(presentation: .named))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ReceiptImageViewer: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                }
                        )
                }
            }
            .navigationTitle("Receipt Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Receipt.self, configurations: config)
    
    let receipt = Receipt(
        storeName: "Walmart",
        totalAmount: 25.48
    )
    
    let item1 = ReceiptItem(name: "Milk", price: 3.99)
    let item2 = ReceiptItem(name: "Bread", price: 2.49, currentWebPrice: 2.29)
    
    receipt.items = [item1, item2]
    container.mainContext.insert(receipt)
    
    return NavigationStack {
        ReceiptDetailView(receipt: receipt)
    }
    .modelContainer(container)
}
