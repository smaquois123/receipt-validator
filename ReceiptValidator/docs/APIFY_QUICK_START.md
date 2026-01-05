# Quick Start: Apify for Walmart Receipt Validation

## Why Apify?

You identified the problem: **"Seagrams" returns 15 products** - name matching fails without UPC search.

**Apify solves this**: Search Walmart.com by UPC code → Get exact product → Validate price

## Setup (10 Minutes)

### Step 1: Sign Up for Apify (2 min)

1. Go to https://apify.com/
2. Click "Sign up free"
3. Verify email
4. **Get $5 free credit** (~500 product lookups)

### Step 2: Get API Token (1 min)

1. Go to https://console.apify.com/account/integrations
2. Copy your API token
3. Should look like: `apify_api_ABCdef123456...`

### Step 3: Add to Your App (2 min)

**Option A: Use plist (easiest)**

1. Create file: `ScrapingAPIs.plist`
2. Add this content:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>ApifyAPIToken</key>
	<string>YOUR_APIFY_TOKEN_HERE</string>
</dict>
</plist>
```

3. Add to `.gitignore`:
```
ScrapingAPIs.plist
```

**Option B: Use xcconfig**

Add to `Config.xcconfig`:
```
APIFY_API_TOKEN = your_token_here
```

Then add to `Info.plist`:
- Key: `APIFY_API_TOKEN`
- Value: `$(APIFY_API_TOKEN)`

### Step 4: Test It (5 min)

Add this test code somewhere:

```swift
import SwiftUI

struct ApifyTestView: View {
    @State private var result = "Not tested yet"
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Apify Test")
                .font(.title)
            
            Button("Test UPC Search") {
                testApify()
            }
            .buttonStyle(.borderedProminent)
            
            Text(result)
                .padding()
                .multilineTextAlignment(.center)
        }
    }
    
    func testApify() {
        Task {
            do {
                let service = ApifyWalmartService()
                
                // Test with Coca-Cola UPC
                let product = try await service.searchByUPC("012000161292")
                
                result = """
                ✅ Success!
                
                Product: \(product.name)
                Price: $\(product.price)
                UPC: \(product.upc ?? "N/A")
                """
            } catch {
                result = "❌ Error: \(error.localizedDescription)"
            }
        }
    }
}
```

Run it. If you see product details, **it's working!**

---

## Usage in Your App

### Validate a Single Item

```swift
let service = ApifyWalmartService()

// With UPC (best!)
if let upc = item.upc {
    let product = try await service.searchByUPC(upc)
    
    if item.price > product.price + 0.50 {
        // Possible overcharge!
        print("⚠️ Receipt: $\(item.price)")
        print("   Website: $\(product.price)")
        print("   Difference: $\(item.price - product.price)")
    }
}
```

### Validate Entire Receipt

```swift
let service = ApifyWalmartService()

for item in receipt.items {
    let result = try await service.validateReceiptItem(item)
    
    switch result.status {
    case .possibleOvercharge:
        print("⚠️ \(item.name): \(result.notes)")
        flaggedItems.append(result)
        
    case .significantOvercharge:
        print("🚨 \(item.name): \(result.notes)")
        flaggedItems.append(result)
        
    default:
        print("✅ \(item.name): OK")
    }
    
    // Rate limiting
    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
}

print("\nFound \(flaggedItems.count) potential overcharges")
```

---

## How It Solves Your Problem

### Before (FireCrawl):
```
"Seagrams" → Search Walmart.com → 15 results
→ Scrape all 15 pages ($0.15!)
→ Try to match UPC
→ Maybe find the right one?
```

**Problems:**
- ❌ Expensive (15 scrapes)
- ❌ Slow (many requests)
- ❌ Unreliable (might not find match)

### After (Apify):
```
UPC "012345678912" → Search Walmart.com → 1 exact result
→ Scrape 1 page ($0.01)
→ Get price
→ Done!
```

**Benefits:**
- ✅ Cheap (1 scrape)
- ✅ Fast (one request)
- ✅ Accurate (exact UPC match)

---

## Cost Breakdown

### Free Tier
- $5 credit included
- ~$0.01 per product lookup
- **500 free lookups**
- Perfect for testing!

### Example Receipt
- 20 items with UPCs
- 20 lookups × $0.01 = **$0.20 per receipt**
- Free tier = 25 receipts free

### Scaling
| Receipts/Month | Items | Cost |
|----------------|-------|------|
| 10 | 200 | **$0** (free) |
| 50 | 1,000 | **$10** |
| 100 | 2,000 | **$20** |
| 500 | 10,000 | **$100** |

At $49/month subscription, you get better rates.

---

## Finding the Right Walmart Actor

In Apify console:

1. Go to https://apify.com/store
2. Search "walmart"
3. Popular options:
   - **`junglee/walmart-scraper`** - Most popular
   - **`epctex/walmart-scraper`** - Well-maintained
   - **`voyager/walmart-scraper`** - Fast

### Test an Actor

```bash
# Replace {actor-id} with the actor you choose
curl -X POST https://api.apify.com/v2/acts/{actor-id}/runs \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "startUrls": [{"url": "https://www.walmart.com/search?q=012000161292"}],
    "maxItems": 1,
    "proxyConfiguration": {"useApifyProxy": true}
  }'
```

Update the `actorId` in `ApifyWalmartService.swift` if needed.

---

## Troubleshooting

### "API token is missing"
- Check `ScrapingAPIs.plist` exists and is added to target
- Verify token is correct (starts with `apify_api_`)
- Check `AppConfiguration.ApifyAPIToken` is not empty

### "Actor not found"
- Verify actor ID is correct
- Try different actor from Apify store
- Update `actorId` in service initialization

### "Timeout" errors
- Apify actors can take 5-30 seconds
- Increase timeout if needed
- Consider running validations in background

### "Product not found"
- UPC might not be on Walmart.com
- Try searching manually to verify
- Fall back to name search

---

## Next Steps

1. ✅ **Sign up for Apify** (free)
2. ✅ **Add API token** to your app
3. ✅ **Run test** with sample UPC
4. ✅ **Validate a real receipt**
5. ✅ **Check flagged items** manually to verify

Once working:
- Integrate into your receipt flow
- Add UI to show validation results
- Track how many overcharges you catch!

---

## Files Created for You

- ✅ `ApifyWalmartService.swift` - Complete implementation
- ✅ `APIFY_VS_OXYLABS.md` - Service comparison
- ✅ This quick start guide

You're ready to go! Just add your API token and test it.

## Questions?

- Apify docs: https://docs.apify.com/
- Walmart scraper examples: Search "walmart" in Apify store
- Rate limits: https://docs.apify.com/platform/limits

**The "Seagrams" problem is solved with UPC search!** 🎉
