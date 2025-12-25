//
//  ReceiptParser.swift
//  ReceiptValidator
//
//  Created by JC Smith on 12/23/25.
//

import Foundation

/// Advanced receipt parsing with store-specific logic
struct ReceiptParser {
    
    /// Parses raw OCR text into structured data with store-specific rules
    static func parse(_ text: String) -> ScannedReceiptData {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // Detect store
        let store = detectStore(from: lines)
        
        // Parse based on store format
        switch store {
        case .walmart:
            return parseWalmart(lines: lines)
        case .target:
            return parseTarget(lines: lines)
        case .costco:
            return parseCostco(lines: lines)
        default:
            return parseGeneric(lines: lines)
        }
    }
    
    // MARK: - Store Detection
    
    private static func detectStore(from lines: [String]) -> RetailerType {
        let combinedText = lines.joined(separator: " ").lowercased()
        
        if combinedText.contains("walmart") || combinedText.contains("wal-mart") {
            return .walmart
        } else if combinedText.contains("target") {
            return .target
        } else if combinedText.contains("costco") {
            return .costco
        } else if combinedText.contains("kroger") {
            return .kroger
        } else if combinedText.contains("safeway") {
            return .safeway
        } else if combinedText.contains("whole foods") {
            return .wholeFoods
        } else if combinedText.contains("atwoods") {
            return .atwoods
        } else if combinedText.contains("tractor supply") {
            return .tractorSupply
        } else if combinedText.contains("home depot") {
            return .homeDepot
        } else if combinedText.contains("lowes") {
            return .lowes
        }
        
        return .unknown
    }
    
    // MARK: - Walmart Specific
    
    private static func parseWalmart(lines: [String]) -> ScannedReceiptData {
        var items: [ScannedItem] = []
        var total: Double?
        
        for line in lines {
            // Skip header/footer lines
            if line.lowercased().contains("walmart") ||
               line.lowercased().contains("save money") ||
               line.lowercased().contains("thank you") {
                continue
            }
            
            // Extract total
            if line.lowercased().contains("total") {
                if let price = extractPrice(from: line) {
                    total = price
                }
                continue
            }
            
            // Skip tax lines
            if line.lowercased().contains("tax") {
                continue
            }
            
            // Parse item line: "ITEM NAME 001234567890 12.99"
            // Walmart format: Item name, then item number (UPC/SKU), then price
            if let price = extractPrice(from: line) {
                var name = removePriceFromLine(line)
                
                // Remove item numbers (typically 10-13 digits for UPC codes)
                name = removeItemNumber(from: name)
                
                if !name.isEmpty && name.count > 2 {
                    items.append(ScannedItem(name: name, price: price))
                }
            }
        }
        
        return ScannedReceiptData(
            storeName: "Walmart",
            items: items,
            totalAmount: total,
            rawText: lines.joined(separator: "\n")
        )
    }
    
    // MARK: - Target Specific
    
    private static func parseTarget(lines: [String]) -> ScannedReceiptData {
        var items: [ScannedItem] = []
        var total: Double?
        
        for line in lines {
            if line.lowercased().contains("target") {
                continue
            }
            
            if line.lowercased().contains("total") {
                if let price = extractPrice(from: line) {
                    total = price
                }
                continue
            }
            
            if let price = extractPrice(from: line) {
                let name = removePriceFromLine(line)
                if !name.isEmpty {
                    items.append(ScannedItem(name: name, price: price))
                }
            }
        }
        
        return ScannedReceiptData(
            storeName: "Target",
            items: items,
            totalAmount: total,
            rawText: lines.joined(separator: "\n")
        )
    }
    
    // MARK: - Costco Specific
    
    private static func parseCostco(lines: [String]) -> ScannedReceiptData {
        var items: [ScannedItem] = []
        var total: Double?
        
        // Costco format often has item numbers
        for line in lines {
            if line.lowercased().contains("costco") {
                continue
            }
            
            if line.lowercased().contains("total") {
                if let price = extractPrice(from: line) {
                    total = price
                }
                continue
            }
            
            // Skip lines that are ONLY numbers (membership numbers, etc.)
            // But don't skip lines that start with numbers and have more content
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.count < 10 && trimmedLine.allSatisfy({ $0.isNumber || $0.isWhitespace }) {
                continue
            }
            
            if let price = extractPrice(from: line) {
                let name = removePriceFromLine(line)
                if !name.isEmpty {
                    items.append(ScannedItem(name: name, price: price))
                }
            }
        }
        
        return ScannedReceiptData(
            storeName: "Costco",
            items: items,
            totalAmount: total,
            rawText: lines.joined(separator: "\n")
        )
    }
    
    // MARK: - Generic Parser
    
    private static func parseGeneric(lines: [String]) -> ScannedReceiptData {
        var items: [ScannedItem] = []
        var storeName: String?
        var total: Double?
        
        // First line is often store name
        if let firstLine = lines.first, firstLine.count < 50 {
            storeName = firstLine
        }
        
        for line in lines {
            // Skip common non-item lines
            let lowercased = line.lowercased()
            if lowercased.contains("thank you") ||
               lowercased.contains("receipt") ||
               lowercased.contains("cashier") ||
               lowercased.contains("store #") ||
               line.contains("****") ||
               line.contains("====") {
                continue
            }
            
            // Extract total
            if lowercased.contains("total") && !lowercased.contains("subtotal") {
                if let price = extractPrice(from: line) {
                    total = price
                }
                continue
            }
            
            // Skip tax lines
            if lowercased.contains("tax") {
                continue
            }
            
            // Parse items
            if let price = extractPrice(from: line) {
                let name = removePriceFromLine(line)
                // Filter out lines that are likely not items
                if !name.isEmpty && name.count > 2 && name.count < 100 {
                    items.append(ScannedItem(name: name, price: price))
                }
            }
        }
        
        return ScannedReceiptData(
            storeName: storeName,
            items: items,
            totalAmount: total,
            rawText: lines.joined(separator: "\n")
        )
    }
    
    // MARK: - Helper Methods
    
    private static func extractPrice(from line: String) -> Double? {
        // Patterns to match: $12.99, 12.99, $1.99, 1.99
        let patterns = [
            #"\$\s*(\d+\.\d{2})"#,  // $12.99 or $ 12.99
            #"(\d+\.\d{2})\s*$"#,    // 12.99 at end of line
            #"\s(\d+\.\d{2})\s"#     // 12.99 with spaces
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let nsString = line as NSString
                let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsString.length))
                
                // Get last match (rightmost price)
                if let match = matches.last, match.numberOfRanges > 1 {
                    let priceString = nsString.substring(with: match.range(at: 1))
                    if let price = Double(priceString) {
                        return price
                    }
                }
            }
        }
        
        return nil
    }
    
    private static func removePriceFromLine(_ line: String) -> String {
        // Remove common price patterns
        let patterns = [
            #"\$\s*\d+\.\d{2}"#,
            #"\d+\.\d{2}\s*$"#,
            #"\s+\d+\.\d{2}\s+"#
        ]
        
        var cleaned = line
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(location: 0, length: cleaned.utf16.count)
                cleaned = regex.stringByReplacingMatches(in: cleaned, range: range, withTemplate: "")
            }
        }
        
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
    
    private static func removeItemNumber(from line: String) -> String {
        // Remove item numbers (UPC codes, SKUs)
        // Matches sequences of 8-14 digits (typical for UPC-A, UPC-E, EAN codes)
        let pattern = #"\b\d{8,14}\b"#
        
        var cleaned = line
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(location: 0, length: cleaned.utf16.count)
            cleaned = regex.stringByReplacingMatches(in: cleaned, range: range, withTemplate: "")
        }
        
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Retailer Types

enum RetailerType {
    case walmart
    case target
    case costco
    case kroger
    case safeway
    case wholeFoods
    case atwoods
    case tractorSupply
    case homeDepot
    case lowes
    case unknown
    
    var displayName: String {
        switch self {
        case .walmart: return "Walmart"
        case .target: return "Target"
        case .costco: return "Costco"
        case .kroger: return "Kroger"
        case .safeway: return "Safeway"
        case .wholeFoods: return "Whole Foods"
        case .atwoods: return "Atwoods"
        case .tractorSupply: return "Tractor Supply"
        case .homeDepot: return "Home Depot"
        case .lowes: return "Lowes"
        case .unknown: return "Unknown Store"
        }
    }
}
