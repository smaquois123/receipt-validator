//
//  ReceiptCaptureView.swift
//  ReceiptValidator
//
//  Created by JC Smith on 12/23/25.
//

import SwiftUI
import PhotosUI
import SwiftData

struct ReceiptCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var scanner = ReceiptScannerService()
    
    @State private var selectedRetailer: RetailerType?
    @State private var showRetailerSelection = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var receiptImage: UIImage?
    @State private var showCamera = false
    @State private var scannedData: ScannedReceiptData?
    @State private var showResults = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let image = receiptImage {
                    // Show captured/selected image
                    ScrollView {
                        VStack(spacing: 16) {
                            // Retailer selection badge
                            if let retailer = selectedRetailer {
                                HStack {
                                    Image(systemName: retailer.iconName)
                                        .foregroundStyle(retailer.color)
                                    Text(retailer.displayName)
                                        .font(.headline)
                                    Spacer()
                                    Button("Change") {
                                        showRetailerSelection = true
                                    }
                                    .font(.subheadline)
                                }
                                .padding()
                                .background {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(retailer.color.opacity(0.1))
                                }
                                .padding(.horizontal)
                            } else {
                                // Prompt to select retailer
                                Button {
                                    showRetailerSelection = true
                                } label: {
                                    HStack {
                                        Image(systemName: "cart.badge.questionmark")
                                            .foregroundStyle(.orange)
                                        Text("Select Retailer")
                                            .font(.headline)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                    .background {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(.orange.opacity(0.1))
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 400)
                                .cornerRadius(12)
                                .shadow(radius: 4)
                            
                            if scanner.isProcessing {
                                VStack(spacing: 12) {
                                    ProgressView()
                                        .scaleEffect(1.2)
                                    Text("Scanning receipt...")
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                            }
                            
                            if let error = scanner.errorMessage {
                                Text(error)
                                    .foregroundStyle(.red)
                                    .padding()
                            }
                        }
                        .padding()
                    }
                } else {
                    // Show selection options
                    VStack(spacing: 30) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 80))
                            .foregroundStyle(.blue)
                        
                        Text("Scan Your Receipt")
                            .font(.title2.bold())
                        
                        Text("Take a photo or select one from your library")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        
                        VStack(spacing: 16) {
                            Button {
                                showCamera = true
                            } label: {
                                Label("Take Photo", systemImage: "camera.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            
                            PhotosPicker(
                                selection: $selectedPhoto,
                                matching: .images
                            ) {
                                Label("Choose from Library", systemImage: "photo.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Scan Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                if receiptImage != nil && !scanner.isProcessing {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Scan") {
                            Task {
                                await scanReceipt()
                            }
                        }
                        .disabled(selectedRetailer == nil)
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraView { image in
                    receiptImage = image
                }
            }
            .sheet(isPresented: $showRetailerSelection) {
                RetailerSelectionView(selectedRetailer: $selectedRetailer)
            }
            .navigationDestination(isPresented: $showResults) {
                if let scannedData = scannedData {
                    ReceiptReviewView(
                        scannedData: scannedData,
                        image: receiptImage
                    )
                }
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    receiptImage = image
                }
            }
        }
        .onChange(of: receiptImage) { oldValue, newValue in
            // Show retailer selection when image is first set
            if oldValue == nil && newValue != nil && selectedRetailer == nil {
                showRetailerSelection = true
            }
        }
    }
    
    private func scanReceipt() async {
        guard let image = receiptImage,
              let retailer = selectedRetailer else { return }
        
        do {
            let data = try await scanner.scanReceipt(from: image, retailer: retailer)
            scannedData = data
            showResults = true
        } catch {
            scanner.errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ReceiptCaptureView()
        .modelContainer(for: Receipt.self, inMemory: true)
}
