//
//  Receipt.swift
//  ReceiptValidator
//
//  Created by JC Smith on 12/23/25.
//

import Foundation
import SwiftData

@Model
final class Receipt {
    var id: UUID
    var timestamp: Date
    var storeName: String?
    var storeLocation: String?
    var totalAmount: Double?
    var imageData: Data?
    var items: [ReceiptItem]
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        storeName: String? = nil,
        storeLocation: String? = nil,
        totalAmount: Double? = nil,
        imageData: Data? = nil,
        items: [ReceiptItem] = []
    ) {
        self.id = id
        self.timestamp = timestamp
        self.storeName = storeName
        self.storeLocation = storeLocation
        self.totalAmount = totalAmount
        self.imageData = imageData
        self.items = items
    }
}

@Model
final class ReceiptItem {
    var id: UUID
    var name: String
    var price: Double
    var quantity: Int
    var upc: String?
    var currentWebPrice: Double?
    var priceComparisonDate: Date?
    var receipt: Receipt?
    
    var priceDifference: Double? {
        guard let webPrice = currentWebPrice else { return nil }
        return price - webPrice
    }
    
    var savingsPercent: Double? {
        guard let webPrice = currentWebPrice, price > 0 else { return nil }
        return ((price - webPrice) / price) * 100
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        price: Double,
        quantity: Int = 1,
        upc: String? = nil,
        currentWebPrice: Double? = nil,
        priceComparisonDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.price = price
        self.quantity = quantity
        self.upc = upc
        self.currentWebPrice = currentWebPrice
        self.priceComparisonDate = priceComparisonDate
    }
}
