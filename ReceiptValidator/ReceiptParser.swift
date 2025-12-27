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
    static func parse(_ text: String, retailer: RetailerType? = nil) -> ScannedReceiptData {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // Use provided retailer or detect store
        let store = retailer ?? detectStore(from: lines)
        
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
        
        // Walmart receipt pattern (tokens on separate lines):
        // GREAT
        // VALUE
        // SUGAR
        // 001234567890  <- SKU/UPC (8-14 digits)
        // 12.99         <- Price
        
        var i = 0
        var itemNameTokens: [String] = []
        
        while i < lines.count {
            let token = lines[i]
            let lowercased = token.lowercased()
            
            // Skip header/footer tokens
            if lowercased.contains("walmart") || 
               lowercased.contains("wal-mart") ||
               lowercased.contains("save") ||
               lowercased.contains("money") ||
               lowercased.contains("live") ||
               lowercased.contains("better") {
                i += 1
                continue
            }
            
            // Check for total
            if lowercased.contains("total") && !lowercased.contains("subtotal") {
                // Look ahead for price
                if i + 1 < lines.count, let price = extractPrice(from: lines[i + 1]) {
                    total = price
                }
                i += 1
                continue
            }
            
            // Skip tax, subtotal, etc.
            if lowercased.contains("tax") || lowercased.contains("subtotal") {
                i += 1
                continue
            }
            
            // Check if this token is a SKU (8-14 digits)
            if isSKU(token) {
                // Look ahead for price on next line
                if i + 1 < lines.count, let price = extractPrice(from: lines[i + 1]) {
                    // We have a complete item: name tokens + SKU + price
                    if !itemNameTokens.isEmpty {
                        let itemName = itemNameTokens.joined(separator: " ")
                        items.append(ScannedItem(name: itemName, price: price, sku: token))
                        itemNameTokens.removeAll()
                    }
                    i += 2 // Skip SKU and price
                    continue
                }
            }
            
            // Check if this token is a price (without a preceding SKU)
            if let price = extractPrice(from: token) {
                // Item without SKU
                if !itemNameTokens.isEmpty {
                    let itemName = itemNameTokens.joined(separator: " ")
                    items.append(ScannedItem(name: itemName, price: price, sku: nil))
                    itemNameTokens.removeAll()
                }
                i += 1
                continue
            }
            
            // Otherwise, it's likely part of an item name
            if !token.isEmpty && token.count > 1 {
                itemNameTokens.append(token)
            }
            
            i += 1
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
        
        // Target format similar to Walmart but may have different SKU patterns
        var i = 0
        var itemNameTokens: [String] = []
        
        while i < lines.count {
            let token = lines[i]
            let lowercased = token.lowercased()
            
            // Skip header
            if lowercased.contains("target") {
                i += 1
                continue
            }
            
            // Check for total
            if lowercased.contains("total") && !lowercased.contains("subtotal") {
                if i + 1 < lines.count, let price = extractPrice(from: lines[i + 1]) {
                    total = price
                }
                i += 1
                continue
            }
            
            // Skip tax
            if lowercased.contains("tax") || lowercased.contains("subtotal") {
                i += 1
                continue
            }
            
            // Check for SKU
            if isSKU(token) {
                if i + 1 < lines.count, let price = extractPrice(from: lines[i + 1]) {
                    if !itemNameTokens.isEmpty {
                        let itemName = itemNameTokens.joined(separator: " ")
                        items.append(ScannedItem(name: itemName, price: price, sku: token))
                        itemNameTokens.removeAll()
                    }
                    i += 2
                    continue
                }
            }
            
            // Check for price
            if let price = extractPrice(from: token) {
                if !itemNameTokens.isEmpty {
                    let itemName = itemNameTokens.joined(separator: " ")
                    items.append(ScannedItem(name: itemName, price: price, sku: nil))
                    itemNameTokens.removeAll()
                }
                i += 1
                continue
            }
            
            // Accumulate name tokens
            if !token.isEmpty && token.count > 1 {
                itemNameTokens.append(token)
            }
            
            i += 1
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
        
        // Costco format with item numbers
        var i = 0
        var itemNameTokens: [String] = []
        
        while i < lines.count {
            let token = lines[i]
            let lowercased = token.lowercased()
            
            // Skip header
            if lowercased.contains("costco") {
                i += 1
                continue
            }
            
            // Check for total
            if lowercased.contains("total") && !lowercased.contains("subtotal") {
                if i + 1 < lines.count, let price = extractPrice(from: lines[i + 1]) {
                    total = price
                }
                i += 1
                continue
            }
            
            // Skip tax, membership numbers
            if lowercased.contains("tax") || lowercased.contains("subtotal") || lowercased.contains("member") {
                i += 1
                continue
            }
            
            // Skip pure numeric lines (membership IDs, etc.) that are short
            if token.count < 10 && token.allSatisfy({ $0.isNumber || $0.isWhitespace }) {
                i += 1
                continue
            }
            
            // Check for SKU
            if isSKU(token) {
                if i + 1 < lines.count, let price = extractPrice(from: lines[i + 1]) {
                    if !itemNameTokens.isEmpty {
                        let itemName = itemNameTokens.joined(separator: " ")
                        items.append(ScannedItem(name: itemName, price: price, sku: token))
                        itemNameTokens.removeAll()
                    }
                    i += 2
                    continue
                }
            }
            
            // Check for price
            if let price = extractPrice(from: token) {
                if !itemNameTokens.isEmpty {
                    let itemName = itemNameTokens.joined(separator: " ")
                    items.append(ScannedItem(name: itemName, price: price, sku: nil))
                    itemNameTokens.removeAll()
                }
                i += 1
                continue
            }
            
            // Accumulate name tokens
            if !token.isEmpty && token.count > 1 {
                itemNameTokens.append(token)
            }
            
            i += 1
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
        
        var i = 0
        var itemNameTokens: [String] = []
        
        while i < lines.count {
            let token = lines[i]
            let lowercased = token.lowercased()
            
            // Skip common non-item tokens
            if lowercased.contains("thank you") ||
               lowercased.contains("receipt") ||
               lowercased.contains("cashier") ||
               lowercased.contains("store #") ||
               token.contains("****") ||
               token.contains("====") {
                i += 1
                continue
            }
            
            // Extract total
            if lowercased.contains("total") && !lowercased.contains("subtotal") {
                if i + 1 < lines.count, let price = extractPrice(from: lines[i + 1]) {
                    total = price
                }
                i += 1
                continue
            }
            
            // Skip tax lines
            if lowercased.contains("tax") {
                i += 1
                continue
            }
            
            // Check for SKU
            if isSKU(token) {
                if i + 1 < lines.count, let price = extractPrice(from: lines[i + 1]) {
                    if !itemNameTokens.isEmpty {
                        let itemName = itemNameTokens.joined(separator: " ")
                        if itemName.count > 2 && itemName.count < 100 {
                            items.append(ScannedItem(name: itemName, price: price, sku: token))
                        }
                        itemNameTokens.removeAll()
                    }
                    i += 2
                    continue
                }
            }
            
            // Check for price
            if let price = extractPrice(from: token) {
                if !itemNameTokens.isEmpty {
                    let itemName = itemNameTokens.joined(separator: " ")
                    if itemName.count > 2 && itemName.count < 100 {
                        items.append(ScannedItem(name: itemName, price: price, sku: nil))
                    }
                    itemNameTokens.removeAll()
                }
                i += 1
                continue
            }
            
            // Accumulate name tokens
            if !token.isEmpty && token.count > 1 {
                itemNameTokens.append(token)
            }
            
            i += 1
        }
        
        return ScannedReceiptData(
            storeName: storeName,
            items: items,
            totalAmount: total,
            rawText: lines.joined(separator: "\n")
        )
    }
    
    // MARK: - Helper Methods
    
    private static func isSKU(_ token: String) -> Bool {
        // Check if token is a valid SKU/UPC (8-14 digits, possibly with dashes)
        let digitsOnly = token.filter { $0.isNumber }
        return digitsOnly.count >= 8 && digitsOnly.count <= 14 && 
               Double(digitsOnly.count) / Double(token.count) > 0.8 // At least 80% digits
    }
    
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

enum RetailerType: Hashable {
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

