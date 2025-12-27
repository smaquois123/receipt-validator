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
    func scanReceipt(from image: UIImage, retailer: RetailerType) async throws -> ScannedReceiptData {
        isProcessing = true
        defer { isProcessing = false }
        
        guard let cgImage = image.cgImage else {
            throw ScannerError.invalidImage
        }
        
        let extractedText = try await recognizeText(from: cgImage)
        let parsedData = parseReceiptText(extractedText, retailer: retailer)
        
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
                
                // Group observations by their vertical position to preserve line structure
                let grouped = self.groupObservationsByLine(observations)
                
                // Join words on same line with space, different lines with newline
                let recognizedText = grouped.map { line in
                    line.map { $0.topCandidates(1).first?.string ?? "" }
                        .joined(separator: " ")
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
    
    /// Groups text observations by their vertical position to identify which words are on the same line
    private func groupObservationsByLine(_ observations: [VNRecognizedTextObservation]) -> [[VNRecognizedTextObservation]] {
        // Sort by Y coordinate (top to bottom - Y increases downward in Vision coordinates)
        let sorted = observations.sorted { $0.boundingBox.midY > $1.boundingBox.midY }
        
        var lines: [[VNRecognizedTextObservation]] = []
        var currentLine: [VNRecognizedTextObservation] = []
        var lastMidY: CGFloat?
        
        for observation in sorted {
            let currentMidY = observation.boundingBox.midY
            
            if let lastY = lastMidY {
                // Calculate threshold based on bounding box height
                // If observations are within 50% of height difference, consider them on the same line
                let threshold = observation.boundingBox.height * 0.5
                
                // If Y difference is small enough, they're on the same line
                if abs(currentMidY - lastY) < threshold {
                    currentLine.append(observation)
                } else {
                    // Start new line
                    if !currentLine.isEmpty {
                        // Sort current line by X coordinate (left to right)
                        lines.append(currentLine.sorted { $0.boundingBox.minX < $1.boundingBox.minX })
                    }
                    currentLine = [observation]
                }
            } else {
                currentLine.append(observation)
            }
            
            lastMidY = currentMidY
        }
        
        // Add the last line
        if !currentLine.isEmpty {
            lines.append(currentLine.sorted { $0.boundingBox.minX < $1.boundingBox.minX })
        }
        
        return lines
    }
    
    /// Parses the extracted text into structured receipt data
    private func parseReceiptText(_ text: String, retailer: RetailerType) -> ScannedReceiptData {
        // Use enhanced parser with store-specific logic
        return ReceiptParser.parse(text, retailer: retailer)
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
    var sku: String?
    
    init(name: String, price: Double, sku: String? = nil) {
        self.name = name
        self.price = price
        self.sku = sku
    }
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
