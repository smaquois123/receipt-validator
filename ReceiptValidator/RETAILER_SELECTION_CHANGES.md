# Retailer Selection Feature

## Overview
Added retailer selection functionality to improve receipt parsing accuracy. Users now select which retailer the receipt is from before scanning, allowing the parser to use store-specific parsing logic.

## Changes Made

### 1. New File: `RetailerSelectionView.swift`
- Created a beautiful grid-based retailer selection interface
- Shows all supported retailers with custom icons and colors
- Uses a 2-column grid layout for easy selection
- Automatically dismisses after selection

**Features:**
- Visual retailer cards with SF Symbols icons
- Color-coded for each retailer (e.g., Walmart = blue, Target = red)
- Clean, modern design with shadows and borders

### 2. Updated: `ReceiptCaptureView.swift`
**Added:**
- `@State private var selectedRetailer: RetailerType?` - Stores selected retailer
- `@State private var showRetailerSelection = false` - Controls sheet presentation
- Retailer selection badge showing the selected store
- "Change" button to reselect retailer
- Warning prompt if no retailer is selected
- Automatic retailer selection sheet when image is captured/selected
- Disabled "Scan" button until retailer is selected

**Flow:**
1. User takes photo or selects from library
2. Retailer selection sheet automatically appears
3. User selects retailer
4. Retailer badge appears above receipt image
5. User can change retailer if needed
6. "Scan" button becomes enabled
7. Receipt is parsed using store-specific logic

### 3. Updated: `ReceiptScannerService.swift`
**Changed:**
- `scanReceipt(from:retailer:)` - Now accepts a `RetailerType` parameter
- `parseReceiptText(_:retailer:)` - Passes retailer to parser

### 4. Updated: `ReceiptParser.swift`
**Changed:**
- `parse(_:retailer:)` - Now accepts optional `RetailerType` parameter
- If retailer is provided, uses it directly instead of detecting
- Falls back to auto-detection if retailer is nil
- `RetailerType` now conforms to `Hashable` for use in SwiftUI views

**Added Extensions:**
- `allRetailers` - Static array of all available retailers
- `iconName` - SF Symbol name for each retailer
- `color` - Brand color for each retailer

## Supported Retailers

| Retailer | Icon | Color |
|----------|------|-------|
| Walmart | cart.fill | Blue |
| Target | target | Red |
| Costco | building.2.fill | Blue |
| Kroger | basket.fill | Blue |
| Safeway | bag.fill | Red |
| Whole Foods | leaf.fill | Green |
| Atwoods | tent.fill | Orange |
| Tractor Supply | wrench.and.screwdriver.fill | Green |
| Home Depot | hammer.fill | Orange |
| Lowe's | house.fill | Blue |
| Unknown | questionmark.square.fill | Gray |

## Benefits

1. **Improved Accuracy**: Store-specific parsing logic is guaranteed to be used
2. **Better User Experience**: Users know exactly which store format will be expected
3. **Debugging**: Easier to troubleshoot parsing issues when store is known
4. **Future-Proof**: Easy to add new retailers with specific parsing rules
5. **Visual Feedback**: Users see their selection throughout the scanning process

## Usage Example

```swift
// In ReceiptCaptureView
@State private var selectedRetailer: RetailerType? = nil

// When scanning
let data = try await scanner.scanReceipt(from: image, retailer: .walmart)
```

## Future Enhancements

- Remember last selected retailer per user
- Add more store logos/branding
- Location-based retailer suggestions
- Barcode scanning to auto-detect retailer
- Store-specific tips for best scan quality
