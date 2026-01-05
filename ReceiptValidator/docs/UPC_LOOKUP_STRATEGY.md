# UPC Lookup Strategy Guide

## The Problem with FireCrawl

You've identified a critical limitation: **FireCrawl can't search directly by UPC code**.

The current workflow is:
1. Search by product name (imprecise)
2. Get multiple results
3. Scrape each result page
4. Try to find UPC code in scraped data
5. Match against your receipt UPC

This is:
- ❌ Inefficient (many unnecessary requests)
- ❌ Expensive (FireCrawl charges per scrape)
- ❌ Slow (multiple round trips)
- ❌ Unreliable (product names may not match)
- ❌ Rate-limited (too many requests)

## Better Solutions

### 🥇 Solution 1: UPC-Specific APIs (Recommended)

Use APIs designed for UPC lookup instead of web scraping:

#### Option A: UPCItemDB (FREE)
- ✅ **Free tier**: 100 requests/day
- ✅ Direct UPC → product info
- ✅ No rate limiting issues
- ❌ Doesn't provide current prices
- 🔗 https://www.upcitemdb.com/

**Use for**: Product name, brand, image
**Then**: Use that info to search retailer sites

#### Option B: Barcode Lookup ($30/month)
- ✅ 500 requests/day
- ✅ Includes price data from multiple retailers
- ✅ Most comprehensive product database
- ✅ Includes retailer links
- ❌ Paid service
- 🔗 https://www.barcodelookup.com/api

**Use for**: Complete solution with prices

#### Option C: Open Food Facts (FREE)
- ✅ Completely free
- ✅ Huge database
- ✅ No API key required
- ❌ Only works for food/grocery items
- 🔗 https://world.openfoodfacts.org/

**Use for**: Grocery items from receipts

#### Option D: Walmart API (FREE but requires approval)
- ✅ Free for affiliates
- ✅ Direct access to Walmart data
- ✅ Real-time prices and availability
- ✅ Direct UPC lookup
- ❌ Requires application/approval
- ❌ May require affiliate links
- 🔗 https://developer.walmart.com/

**Use for**: Walmart receipts (perfect match!)

### 🥈 Solution 2: Hybrid Approach (Best Overall)

Combine multiple services strategically:

```
1. Check if item has UPC code
   ├─ YES → Use UPC lookup service
   │   ├─ Get product name, brand, image
   │   ├─ Use FireCrawl to get current price with exact product info
   │   └─ Much more accurate!
   │
   └─ NO → Fall back to name-based search
       └─ Use FireCrawl with product name only
```

**Benefits**:
- ✅ Fast and accurate for UPC items (95% of receipt items)
- ✅ Falls back gracefully for non-UPC items
- ✅ Reduces FireCrawl usage (saves money)
- ✅ Better product matching

### 🥉 Solution 3: Build Your Own Database

Cache product data locally:

```swift
struct ProductCache {
    let upc: String
    let name: String
    let brand: String
    let retailerURLs: [String: String]  // "walmart": "https://..."
    let lastUpdated: Date
}
```

**Strategy**:
1. First lookup: Use UPC API + FireCrawl, cache result
2. Subsequent lookups: Use cached URL directly
3. Refresh: Only scrape price page (not search)
4. Age out: Refresh URLs older than 30 days

**Benefits**:
- ✅ Near-instant for cached items
- ✅ Minimal API costs after first lookup
- ✅ Works offline for known products

## Recommended Implementation

### Phase 1: Add UPC Lookup (Week 1)
1. Integrate `UPCLookupService.swift` (already created)
2. Sign up for UPCItemDB free tier
3. Use UPC lookup to get accurate product names
4. Use those names with FireCrawl for prices

### Phase 2: Add Caching (Week 2)
1. Create SwiftData model for product cache
2. Store UPC → Product → Retailer URL mappings
3. Check cache before API calls
4. Implement cache refresh strategy

### Phase 3: Add Walmart Direct API (Week 3)
1. Apply for Walmart API access
2. Implement direct UPC → price lookup
3. Use for Walmart receipts specifically
4. Fallback to FireCrawl for other retailers

### Phase 4: Optimize (Week 4)
1. Implement batch processing
2. Add request prioritization
3. Implement smart rate limiting
4. Add analytics to track success rates

## Code Integration

### Update AppConfiguration

```swift
struct AppConfiguration {
    // FireCrawl (for web scraping when needed)
    static let fireCrawlApiKey: String = // ... existing code
    
    // UPC Lookup Services (NEW)
    static let upcItemDBApiKey: String = // ... load from config
    static let barcodeLookupApiKey: String = // ... optional paid service
    static let walmartAPIKey: String = // ... when approved
    
    // Strategy settings
    static let preferUPCLookup = true  // Use UPC when available
    static let enableProductCache = true  // Cache product URLs
    static let cacheRefreshDays = 30  // Refresh URLs after 30 days
}
```

### Update Price Comparison Flow

```swift
func comparePrice(for item: ReceiptItem) async -> Double? {
    // 1. Try UPC lookup first
    if let upc = item.upc, AppConfiguration.preferUPCLookup {
        do {
            let upcService = UPCLookupService(
                provider: .hybrid,
                apiKeys: [
                    "upcItemDB": AppConfiguration.upcItemDBApiKey,
                    "walmart": AppConfiguration.walmartAPIKey
                ]
            )
            
            let product = try await upcService.lookupProduct(
                upc: upc,
                retailer: item.receipt?.storeName
            )
            
            // If we got a price directly, use it
            if let price = product.price {
                return price
            }
            
            // Otherwise, use the accurate product info for FireCrawl
            if let url = product.productURL {
                return try await scrapePrice(url: url)
            }
            
            // Use product name for more accurate search
            return try await scrapePrice(
                productName: product.title,
                upcToMatch: upc
            )
        } catch {
            print("UPC lookup failed, falling back to name search")
        }
    }
    
    // 2. Fall back to name-based FireCrawl search
    return try await scrapePrice(productName: item.name)
}
```

## Cost Comparison

### Current (FireCrawl only):
- Search request: $0.01
- Product page scrape: $0.01
- Average per item: $0.02
- 100 items/receipt: **$2.00**

### With UPC Lookup:
- UPC lookup: $0.00 (free tier)
- Product page scrape: $0.01
- Average per item: $0.01
- 100 items/receipt: **$1.00** (50% savings!)

### With UPC + Caching:
- First lookup: $0.01
- Cached lookups: $0.00
- Average per item: $0.002
- 100 items/receipt: **$0.20** (90% savings!)

## API Key Setup

Add these to your `.gitignore`:
```
Config.xcconfig
FireCrawlApi.plist
UPCAPIs.plist
```

Create `UPCAPIs.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>UPCItemDBApiKey</key>
    <string>YOUR_KEY_HERE</string>
    <key>BarcodeLookupApiKey</key>
    <string>YOUR_KEY_HERE</string>
    <key>WalmartAPIKey</key>
    <string>YOUR_KEY_HERE</string>
</dict>
</plist>
```

## Free Tier Limits

| Service | Free Requests | Cost After Limit |
|---------|--------------|------------------|
| UPCItemDB | 100/day | $10/month for 1000/day |
| Open Food Facts | Unlimited | Always free |
| Walmart API | Unlimited* | Free (requires approval) |
| FireCrawl | Pay per use | $0.01/scrape |

*Subject to rate limiting

## Next Steps

1. **Sign up for free services**:
   - UPCItemDB: https://www.upcitemdb.com/
   - Open Food Facts: No signup needed

2. **Integrate UPCLookupService** (already created for you)

3. **Update ReceiptValidatorService** to use hybrid approach

4. **Test with real receipts**

5. **Monitor usage and costs**

6. **Consider paid services** if you need more capacity

## Testing

Create a test view to verify UPC lookup:

```swift
struct UPCTestView: View {
    @State private var upc = "012000161292" // Coke UPC
    @State private var result: String = ""
    
    var body: some View {
        VStack {
            TextField("Enter UPC", text: $upc)
            Button("Lookup") {
                Task {
                    let service = UPCLookupService(
                        provider: .openFoodFacts
                    )
                    let product = try await service.lookupProduct(upc: upc)
                    result = "\(product.title) - \(product.brand ?? "No brand")"
                }
            }
            Text(result)
        }
    }
}
```

## Summary

**Replace FireCrawl name searches with UPC lookups** for:
- ⚡️ Faster lookups
- 💰 Lower costs  
- 🎯 More accurate matching
- 📊 Better data quality

The hybrid approach gives you the best of both worlds!
