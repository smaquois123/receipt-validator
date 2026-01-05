# Receipt Validator - FireCrawl Integration

## Overview

The Receipt Validator app now includes price validation using **FireCrawl**, a web scraping API that can extract structured product data from retailer websites like Walmart, Target, and Costco.

## Flow After ReceiptParser

Here's the complete flow with FireCrawl integration:

```
1. User captures receipt image (CameraView or PhotosPicker)
   ↓
2. User selects retailer (RetailerSelectionView)
   ↓
3. Vision framework extracts text (ReceiptScannerService)
   ↓
4. ⭐ ReceiptParser.parse() ⭐ parses text into ScannedReceiptData
   ↓
5. ReceiptReviewView displays parsed data for editing
   ↓
6. [NEW] User taps "Validate Prices" button
   ↓
7. ReceiptValidatorService uses FireCrawl to:
   - Search for each product on retailer's website
   - Extract current online price
   - Compare with receipt price
   - Calculate price differences
   ↓
8. ValidationResultsView shows:
   - Price comparison summary
   - Individual item validations
   - Confidence scores
   - Links to products online
   ↓
9. User saves receipt to SwiftData
   ↓
10. Receipt appears in ContentView list
```

## Setup Instructions

### 1. Get FireCrawl API Key

1. Go to [https://firecrawl.dev](https://firecrawl.dev)
2. Sign up for an account
3. Navigate to your dashboard
4. Copy your API key

### 2. Configure API Key

**Option A: Using APIKeys.plist (Recommended for development)**

1. Create a new file: `APIKeys.plist` in your project
2. Add it to `.gitignore` to keep it private
3. Add the following structure:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>FireCrawlAPIKey</key>
    <string>YOUR_API_KEY_HERE</string>
</dict>
</plist>
```

**Option B: Using Environment Variables (Recommended for production)**

Set the `FIRECRAWL_API_KEY` environment variable:

```bash
export FIRECRAWL_API_KEY="your_api_key_here"
```

### 3. Add to .gitignore

Add these lines to your `.gitignore`:

```
# API Keys
APIKeys.plist
```

## Architecture

### New Files Created

1. **FireCrawlService.swift**
   - Handles all FireCrawl API communication
   - Scrapes product data from Walmart, Target, Costco
   - Parses HTML/Markdown to extract prices
   - Supports multiple retailers

2. **AppConfiguration.swift**
   - Centralized configuration management
   - Secure API key handling
   - Feature flags and settings

3. **ValidationResultsView.swift**
   - Displays validation results in a user-friendly format
   - Shows price comparisons
   - Provides links to products online
   - Color-coded confidence indicators

### Updated Files

1. **ReceiptValidatorService.swift**
   - Integrated FireCrawl for actual price validation
   - Removed mock implementation
   - Added retailer-specific validation logic
   - Calculates price differences and confidence scores

2. **ReceiptReviewView.swift**
   - Added "Validate Prices" button
   - Shows validation progress
   - Displays validation results sheet
   - Passes retailer information

3. **ReceiptCaptureView.swift**
   - Passes retailer to ReceiptReviewView

## How It Works

### 1. FireCrawl Scraping Process

```swift
// User searches for product
fireCrawl.scrapeWalmartProduct(searchQuery: "Milk")
    ↓
// FireCrawl searches Walmart.com
"https://www.walmart.com/search?q=Milk"
    ↓
// Extracts product URL from search results
"https://www.walmart.com/ip/Great-Value-Whole-Milk/12345"
    ↓
// Scrapes product page
FireCrawl returns HTML + Markdown
    ↓
// Parses price from content
extractPrice() finds "$3.49"
    ↓
// Returns WalmartProductData
{
    name: "Great Value Whole Milk",
    price: 3.49,
    upc: "078742123456",
    inStock: true
}
```

### 2. Price Comparison Logic

```swift
// Receipt shows: Milk $3.99
// Online price: $3.49
// Difference: $0.50 (paid more)

priceDifference = receiptPrice - onlinePrice
percentageDiff = abs(priceDifference / receiptPrice * 100)

if percentageDiff <= 10% {
    isValid = true  // Prices match within tolerance
} else {
    isValid = false // Significant price difference
}
```

### 3. Confidence Scoring

The system calculates confidence based on:
- Product name matching (word overlap)
- UPC/SKU matching (if available)
- Price reasonableness
- Stock status

```swift
confidence = calculateNameMatchConfidence(
    receiptName: "MILK WHOLE GLN",
    productName: "Great Value Whole Milk Gallon"
)
// Returns: 0.85 (85% confidence)
```

## Usage

### In ReceiptReviewView

1. After scanning and reviewing your receipt
2. Tap "Validate Prices"
3. Wait for validation to complete (progress bar shows status)
4. View validation results sheet
5. See price comparisons and discrepancies
6. Optionally visit product pages online
7. Save receipt

### Validation Results Show

- ✅ **Validated Items**: Prices match or are within tolerance
- ⚠️ **Low Confidence**: Product match uncertain
- ❌ **Could Not Validate**: Product not found online

For each item:
- Receipt price vs Current online price
- Price difference (with ↑ or ↓ indicator)
- Confidence percentage
- Validation message
- Link to product page
- Stock status

## Rate Limiting

To avoid overwhelming the FireCrawl API:
- 1-second delay between validation requests
- Configurable via `AppConfiguration.validationDelay`
- Progress indicator shows real-time status

## Error Handling

The system gracefully handles:
- Product not found online
- Network timeouts
- API rate limits
- Parsing errors
- Invalid responses

Errors are logged and displayed to the user with helpful messages.

## Customization

### Adjust Price Tolerance

In `AppConfiguration.swift`:

```swift
static let priceTolerancePercentage: Double = 0.10 // 10%
```

### Change Validation Delay

```swift
static let validationDelay: TimeInterval = 1.0 // seconds
```

### Add More Retailers

In `FireCrawlService.swift`, add methods like:

```swift
func scrapeKrogerProduct(searchQuery: String) async throws -> ProductData? {
    // Implementation
}
```

Then update `ReceiptValidatorService.swift`:

```swift
case .kroger:
    return await validateKrogerItem(item)
```

## Cost Considerations

FireCrawl pricing (as of Jan 2026):
- Free tier: 500 credits/month
- Each scrape = ~1-2 credits
- Monitor usage via FireCrawl dashboard

Tips to minimize costs:
- Cache validation results
- Only validate when user requests
- Consider batch processing
- Use price history to avoid re-checking

## Future Enhancements

1. **Cache validation results**
   - Store in SwiftData
   - Expire after X hours
   - Avoid duplicate checks

2. **Batch validation**
   - Validate multiple items concurrently
   - Use `maxConcurrentValidations` setting

3. **Price history tracking**
   - Store historical prices
   - Show trends over time
   - Alert on price drops

4. **Smart product matching**
   - Use fuzzy string matching
   - Learn from user corrections
   - Suggest alternatives

5. **UPC scanning**
   - Scan barcodes directly
   - More accurate product matching
   - Better confidence scores

## Troubleshooting

### "API key is missing" error
- Check APIKeys.plist exists and has correct format
- Verify API key is valid on firecrawl.dev
- Check environment variable is set

### "Product not found" for all items
- Verify retailer website is accessible
- Check FireCrawl service is operational
- Review product name formatting from ReceiptParser

### Slow validation
- Expected: ~1-2 seconds per item
- Check network connection
- Verify FireCrawl API status
- Consider reducing number of items

### Low confidence scores
- Improve ReceiptParser accuracy
- Clean up product names before validation
- Consider manual name corrections

## Support

For FireCrawl API issues:
- Documentation: https://docs.firecrawl.dev
- Support: https://firecrawl.dev/support

For app-specific questions:
- Review code comments
- Check inline documentation
- Test with sample receipts

## Privacy & Terms of Service

⚠️ **Important**: Ensure you comply with:
- FireCrawl Terms of Service
- Retailer website Terms of Use
- User privacy requirements
- Data retention policies

Always:
- Respect rate limits
- Cache responsibly
- Disclose data collection to users
- Handle user data securely
