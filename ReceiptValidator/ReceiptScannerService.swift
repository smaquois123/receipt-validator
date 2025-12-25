//
//  ReceiptScannerService.swift
//  ReceiptValidator
//
//  Created by JC Smith on 12/23/25.
//

import Vision
import UIKit
import SwiftUI
internal import Combine

@MainActor
class ReceiptScannerService: ObservableObject {
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    /// Scans a receipt image and extracts text using Vision framework
    func scanReceipt(from image: UIImage) async throws -> ScannedReceiptData {
        isProcessing = true
        defer { isProcessing = false }
        
        guard let cgImage = image.cgImage else {
            throw ScannerError.invalidImage
        }
        
        let extractedText = try await recognizeText(from: cgImage)
        let parsedData = parseReceiptText(extractedText)
        
        return parsedData
    }
    
    /// Uses Vision framework to recognize text in the image
    private func recognizeText(from cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: ScannerError.noTextFound)
                    return
                }
                
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                continuation.resume(returning: recognizedText)
            }
            
            // Configure for accurate recognition
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Parses the extracted text into structured receipt data
    private func parseReceiptText(_ text: String) -> ScannedReceiptData {
        // Use enhanced parser with store-specific logic
        return ReceiptParser.parse(text)
    }
}

// MARK: - Supporting Types

struct ScannedReceiptData {
    var storeName: String?
    var items: [ScannedItem]
    var totalAmount: Double?
    var rawText: String
}

struct ScannedItem {
    var name: String
    var price: Double
}

enum ScannerError: LocalizedError {
    case invalidImage
    case noTextFound
    case parsingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The provided image is invalid"
        case .noTextFound:
            return "No text was found in the image"
        case .parsingFailed:
            return "Failed to parse the receipt data"
        }
    }
}
