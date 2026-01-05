# Receipt Validator App - Complete Flow Documentation

## Overview

This document describes the complete flow of the Receipt Validator app, from image capture through price validation using FireCrawl.

---

## 📱 User Journey

### Phase 1: Receipt Capture
**File: ContentView.swift → ReceiptCaptureView.swift**

1. User opens app → sees receipt list
2. Taps "Scan Receipt" button
3. Chooses to:
   - Take photo with camera (CameraView)
   - Select from photo library (PhotosPicker)

### Phase 2: Retailer Selection
**File: RetailerSelectionView.swift**

4. App prompts user to select retailer:
   - Walmart
   - Target
   - Costco
   - Kroger
   - Safeway
   - And more...

### Phase 3: OCR Text Extraction
**File: ReceiptScannerService.swift**

5. Vision framework processes image:
   ```swift
   VNRecognizeTextRequest extracts text
   → Groups observations by line
   → Returns structured text string
   ```

### Phase 4: ⭐ Receipt Parsing ⭐
**File: ReceiptParser.swift (Your Focus)**

6. **ReceiptParser.parse(text, retailer)** is invoked:
   ```swift
   Input:  Raw OCR text + RetailerType
   Process: 
     - Detects store name
     - Identifies items and prices
     - Extracts total amount
     - Removes noise (dates, SKUs, etc.)
   Output: ScannedReceiptData {
     storeName: String?
     items: [ScannedItem]
     totalAmount: Double?
     rawText: String
   }
   ```

### Phase 5: Review & Edit
**File: ReceiptReviewView.swift**

7. User reviews parsed data:
   - Edit store name
   - Correct item names
   - Adjust prices
   - Add/remove items
   - View raw OCR text

### Phase 6: 🆕 Price Validation (NEW!)
**Files: ReceiptValidatorService.swift + FireCrawlService.swift**

8. User taps **"Validate Prices"** button
9. For each item on receipt:
   ```swift
   FireCrawl scrapes retailer website
   → Searches for product by name
   → Extracts current online price
   → Compares with receipt price
   → Calculates difference
   ```

10. Validation process:
    ```
    Receipt Item: "MILK WHOLE" $3.99
          ↓
    FireCrawl searches Walmart.com
          ↓
    Finds: "Great Value Whole Milk Gallon" $3.49
          ↓
    Calculates:
      - Difference: $0.50 (paid $0.50 more)
      - Confidence: 85% (good name match)
      - Status: Valid (within 10% tolerance)
    ```

### Phase 7: Validation Results
**File: ValidationResultsView.swift**

11. Shows comprehensive results:
    - **Summary**: Overall validation rate
    - **Price Comparison**: Total paid vs current online
    - **Per-Item Analysis**:
      - ✅ Validated (good match)
      - ⚠️ Low confidence (uncertain)
      - ❌ Not found (product not online)
    - Links to products online
    - Stock status

### Phase 8: Save to Database
**File: ReceiptReviewView.swift**

12. User taps "Save"
13. Creates SwiftData models:
    ```swift
    Receipt {
      timestamp, storeName, totalAmount, imageData
    }
    ReceiptItem[] {
      name, price, currentWebPrice, priceDifference
    }
    ```

14. Persists to SwiftData

### Phase 9: View & Compare
**Files: ContentView.swift → ReceiptDetailView.swift**

15. Receipt appears in main list
16. User can:
    - View receipt image
    - See all items
    - Check prices again later
    - Compare historical prices

---

## 🔄 Technical Flow Diagram

```
┌─────────────────┐
│  ContentView    │ User taps "Scan Receipt"
└────────┬────────┘
         │
         ▼
┌─────────────────────┐
│ ReceiptCaptureView  │ Capture/select image
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│RetailerSelectionView│ Choose store
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│ReceiptScannerService│ Vision OCR
└────────┬────────────┘
         │ extractedText: String
         ▼
┌─────────────────────┐
│  ⭐ ReceiptParser ⭐ │ Parse text
└────────┬────────────┘
         │ ScannedReceiptData
         ▼
┌─────────────────────┐
│ ReceiptReviewView   │ Edit & review
└────────┬────────────┘
         │
         ├──────────────────┐
         │                  │
         ▼                  ▼
┌────────────────┐   ┌─────────────────────────┐
│ Save to DB     │   │ Validate Prices (NEW!)  │
└────────┬───────┘   └──────────┬──────────────┘
         │                      │
         │                      ▼
         │           ┌─────────────────────────┐
         │           │ReceiptValidatorService  │
         │           └──────────┬──────────────┘
         │                      │
         │                      ▼
         │           ┌─────────────────────────┐
         │           │   FireCrawlService      │
         │           │   - Search product      │
         │           │   - Extract price       │
         │           │   - Compare prices      │
         │           └──────────┬──────────────┘
         │                      │
         │                      ▼
         │           ┌─────────────────────────┐
         │           │ ValidationResultsView   │
         │           │   - Show differences    │
         │           │   - Display confidence  │
         │           │   - Link to products    │
         │           └─────────────────────────┘
         │
         ▼
┌─────────────────┐
│  ContentView    │ Shows saved receipt
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ReceiptDetailView│ View details, compare prices
└─────────────────┘
```

---

## 🔑 Key Components

### Data Models

```swift
// After ReceiptParser
ScannedReceiptData {
    storeName: String?
    items: [ScannedItem {
        name: String
        price: Double
        sku: String?
    }]
    totalAmount: Double?
    rawText: String
}

// After Validation
ValidatedItem {
    item: ScannedItem
    isValid: Bool
    confidence: Double
    validationMessage: String?
    currentOnlinePrice: Double?      // NEW!
    priceDifference: Double?         // NEW!
    productURL: String?              // NEW!
    inStock: Bool?                   // NEW!
}

// Saved to Database
Receipt {
    timestamp: Date
    storeName: String?
    totalAmount: Double?
    imageData: Data?
    items: [ReceiptItem]
}
```

### Services

1. **ReceiptScannerService** (OCR)
   - Uses Vision framework
   - Extracts text from images
   - Groups text by lines

2. **ReceiptParser** (Your code)
   - Parses OCR text
   - Retailer-specific logic
   - Extracts items and prices

3. **FireCrawlService** (NEW!)
   - Web scraping via FireCrawl API
   - Searches retailer websites
   - Extracts product data

4. **ReceiptValidatorService** (Updated)
   - Orchestrates validation
   - Uses FireCrawl
   - Compares prices
   - Calculates confidence

5. **PriceComparisonService** (Existing)
   - Checks prices for saved receipts
   - Can be used later for price tracking

---

## 🎯 What Happens After ReceiptParser

### Immediate Next Steps

1. **Data flows to ReceiptReviewView**
   ```swift
   scannedData = ReceiptParser.parse(text, retailer)
   ↓
   ReceiptReviewView(scannedData: scannedData, ...)
   ```

2. **User can validate prices** (Optional)
   ```swift
   validatePrices() calls:
   ↓
   ReceiptValidatorService.validateReceipt(...)
   ↓
   For each item:
     FireCrawlService.scrapeWalmartProduct(item.name)
   ↓
   Returns: ReceiptValidationResult
   ↓
   Shows: ValidationResultsView
   ```

3. **User saves receipt**
   ```swift
   saveReceipt() creates:
   ↓
   Receipt + ReceiptItem[] models
   ↓
   Persists to SwiftData
   ```

### Data Transformation Journey

```
UIImage (receipt photo)
    ↓ Vision OCR
String (raw text)
    ↓ ReceiptParser.parse()
ScannedReceiptData (structured)
    ↓ User editing
EditableItem[] (modified)
    ↓ Validation (optional)
ValidatedItem[] (with online prices)
    ↓ Save
Receipt + ReceiptItem[] (persisted)
```

---

## 🆕 New Features with FireCrawl

### Before (Mock Implementation)
- ❌ No real price checking
- ❌ Mock confidence scores
- ❌ No product URLs
- ❌ No stock information

### After (FireCrawl Integration)
- ✅ Real-time price checking
- ✅ Actual product matching
- ✅ Confidence based on name similarity
- ✅ Links to products online
- ✅ Stock status
- ✅ Price difference calculations
- ✅ Multi-retailer support

---

## 🔧 Configuration

### Setup Requirements

1. **FireCrawl API Key**
   - Sign up at firecrawl.dev
   - Get API key
   - Add to APIKeys.plist or environment variable

2. **App Configuration**
   ```swift
   // In AppConfiguration.swift
   static let fireCrawlAPIKey = "..." // Auto-loaded
   static let priceTolerancePercentage = 0.10
   static let validationDelay = 1.0
   ```

3. **Feature Flags**
   ```swift
   static let enablePriceValidation = true
   static let enablePriceComparison = true
   ```

---

## 📊 Example Validation Flow

### Input (from ReceiptParser)
```swift
ScannedReceiptData(
    storeName: "Walmart",
    items: [
        ScannedItem(name: "MILK WHOLE GLN", price: 3.99),
        ScannedItem(name: "BREAD WHITE", price: 2.49),
        ScannedItem(name: "EGGS LARGE", price: 4.99)
    ],
    totalAmount: 11.47
)
```

### Validation Process
```
Item 1: "MILK WHOLE GLN" $3.99
  → FireCrawl searches Walmart.com
  → Finds "Great Value Whole Milk Gallon" $3.49
  → Difference: +$0.50 (paid more)
  → Confidence: 85%
  → Status: Valid ✅

Item 2: "BREAD WHITE" $2.49
  → FireCrawl searches Walmart.com
  → Finds "Great Value White Bread" $2.49
  → Difference: $0.00 (exact match)
  → Confidence: 92%
  → Status: Valid ✅

Item 3: "EGGS LARGE" $4.99
  → FireCrawl searches Walmart.com
  → Product not found
  → Difference: N/A
  → Confidence: 20%
  → Status: Invalid ❌
```

### Output (ValidationResultsView)
```
✅ Validation Rate: 67% (2 of 3 items)

💰 Price Comparison:
   Total Paid: $11.47
   Current Online: $5.98 (2 items)
   Difference: +$0.50

📦 2 Validated Items
   ✅ MILK WHOLE GLN (+$0.50)
   ✅ BREAD WHITE ($0.00)

❌ 1 Could Not Validate
   ❌ EGGS LARGE (not found)
```

---

## 🚀 Next Steps for You

1. **Test the integration**
   - Get FireCrawl API key
   - Configure APIKeys.plist
   - Scan a test receipt
   - Validate prices

2. **Tune ReceiptParser**
   - Improve name extraction
   - Better price detection
   - Handle edge cases

3. **Optimize validation**
   - Add caching
   - Improve product matching
   - Handle more retailers

4. **Monitor costs**
   - Track FireCrawl usage
   - Optimize scraping patterns
   - Cache results

---

## ❓ Common Questions

**Q: When is price validation triggered?**
A: Only when user taps "Validate Prices" button in ReceiptReviewView. It's optional.

**Q: Can users save without validating?**
A: Yes! Validation is completely optional. Users can save immediately after parsing.

**Q: What if FireCrawl can't find a product?**
A: The item is marked as "Could Not Validate" with low confidence. The receipt is still saved.

**Q: How accurate is the matching?**
A: Depends on product name quality from ReceiptParser. Typical confidence: 70-90% for common items.

**Q: Does this work offline?**
A: No. Price validation requires internet connection. But OCR and parsing work offline.

---

## 📝 Summary

**The complete flow is:**

1. Capture → 2. Select Retailer → 3. OCR → 4. **Parse** → 5. Review → 6. **Validate (NEW!)** → 7. Results → 8. Save → 9. View

**After ReceiptParser, the data:**
- Goes to ReceiptReviewView for editing
- Can be validated with FireCrawl (optional)
- Is saved to SwiftData
- Appears in ContentView list
- Can be viewed in ReceiptDetailView

**Key improvement:**
You now have **real price validation** instead of mock data, using FireCrawl to compare receipt prices with current online prices!
