//
//  ContentView.swift
//  ReceiptValidator
//
//  Created by JC Smith on 12/23/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Receipt.timestamp, order: .reverse) private var receipts: [Receipt]
    
    @State private var showingScanner = false
    @State private var selectedReceipt: Receipt?

    var body: some View {
        NavigationStack {
            Group {
                if receipts.isEmpty {
                    emptyStateView
                } else {
                    receiptListView
                }
            }
            .navigationTitle("Receipts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingScanner = true
                    } label: {
                        Label("Scan Receipt", systemImage: "doc.text.viewfinder")
                    }
                }
                
                if !receipts.isEmpty {
                    ToolbarItem(placement: .secondaryAction) {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showingScanner) {
                ReceiptCaptureView()
            }
            .navigationDestination(item: $selectedReceipt) { receipt in
                ReceiptDetailView(receipt: receipt)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "receipt.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
            
            Text("No Receipts Yet")
                .font(.title2.bold())
            
            Text("Scan your first receipt to start comparing prices")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                showingScanner = true
            } label: {
                Label("Scan Receipt", systemImage: "doc.text.viewfinder")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
    
    private var receiptListView: some View {
        List {
            ForEach(receipts) { receipt in
                Button {
                    selectedReceipt = receipt
                } label: {
                    ReceiptRowView(receipt: receipt)
                }
                .buttonStyle(.plain)
            }
            .onDelete(perform: deleteReceipts)
        }
    }

    private func deleteReceipts(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(receipts[index])
            }
        }
    }
}

struct ReceiptRowView: View {
    let receipt: Receipt
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let imageData = receipt.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "receipt")
                            .foregroundStyle(.secondary)
                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.storeName ?? "Unknown Store")
                    .font(.headline)
                
                Text(receipt.timestamp, format: .dateTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let total = receipt.totalAmount {
                    Text("$\(total, specifier: "%.2f")")
                        .font(.subheadline.bold())
                        .foregroundStyle(.blue)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(receipt.items.count)")
                    .font(.title3.bold())
                Text("items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Receipt.self, inMemory: true)
}
