# Apify vs Oxylabs for Walmart Receipt Validation

## Your Problem

**"Seagrams" returns 15 products** - name matching doesn't work without UPC search capability.

## Solution: Use a service that can search Walmart by UPC

Both Apify and Oxylabs can do this, but here's the breakdown:

---

## Apify ⭐ RECOMMENDED

### What It Is
Web scraping platform with pre-built "actors" (scrapers) including Walmart scrapers

### Can It Search by UPC?
✅ **YES** - Walmart.com accepts UPC in search, Apify scrapes the results

### How It Works
```
1. Build URL: https://www.walmart.com/search?q={UPC}
2. Apify scrapes search results
3. First result = exact product match
4. Returns: name, price, UPC, itemId, URL
5. One API call, instant results
```

### Pricing
- **Free Tier**: $5 credit/month (~500 product lookups)
- **Paid**: $49/month for more usage
- **Per-request**: ~$0.01 per product lookup

### Pros
✅ **Affordable** - Free tier perfect for testing  
✅ **Pre-built Walmart scraper** - No custom code  
✅ **UPC search works perfectly** - Solves your problem  
✅ **Easy API** - Simple REST calls  
✅ **Good documentation** - Quick to integrate  
✅ **Handles anti-bot** - Apify manages proxies/rotation  

### Cons
❌ Async execution (start job → wait → get results)  
❌ 2-5 second latency per lookup  
❌ Community-maintained scrapers (could break with Walmart changes)  

### For Your Use Case
Perfect for:
- Receipt validation (UPC → price)
- Walmart-specific scraping
- Budget-conscious projects
- Prototyping/MVP

---

## Oxylabs

### What It Is
Enterprise web scraping infrastructure with E-Commerce API

### Can It Search by UPC?
✅ **YES** - E-Commerce Scraper can search Walmart products

### How It Works
```
1. API call with UPC as search query
2. Oxylabs scrapes Walmart in real-time
3. Returns structured product data
4. Includes price, title, availability
```

### Pricing
- **Minimum**: $49/month base + usage
- **E-Commerce API**: $1.50 per 1,000 requests  
- **Enterprise tiers**: Higher volume discounts  

### Pros
✅ **Enterprise-grade** - Very reliable  
✅ **Faster response** - Better infrastructure  
✅ **Structured data** - Clean JSON responses  
✅ **Better support** - Dedicated account managers  
✅ **Multiple retailers** - Not just Walmart  
✅ **Maintained by Oxylabs** - Less likely to break  

### Cons
❌ **More expensive** - $49 minimum + $1.50/1000  
❌ **Overkill for single-retailer** - Better for multi-retailer  
❌ **More complex** - More features = more complexity  

### For Your Use Case
Better if:
- You need enterprise reliability
- Planning multi-retailer support (Target, Costco, etc.)
- Higher volume (thousands of receipts/month)
- Budget allows $100+/month

---

## Direct Comparison

| Feature | Apify | Oxylabs |
|---------|-------|---------|
| **Free Tier** | $5 credit (~500 lookups) | None |
| **Minimum Cost** | $0 (free tier) | $49/month |
| **Per-Lookup Cost** | ~$0.01 | ~$0.0015 |
| **UPC Search** | ✅ Yes | ✅ Yes |
| **Setup Difficulty** | Easy | Medium |
| **Latency** | 2-5 seconds | 1-3 seconds |
| **Reliability** | Good | Excellent |
| **Walmart-specific** | Yes (actor available) | Yes (E-Commerce API) |
| **Multi-retailer** | Separate actors needed | Built-in |
| **Proxy Management** | Included | Included |
| **Documentation** | Good | Excellent |

---

## My Recommendation: **Apify**

### Why Apify for You:

1. **FREE to test** ($5 credit = 500 products)
   - Validate entire receipts without paying
   - Prove the concept works
   - Then decide if you want to scale

2. **Solves your UPC problem**
   - Search Walmart by UPC directly
   - "Seagrams" + UPC = exact product match
   - No more 15 ambiguous results

3. **Simple integration**
   - I already wrote `ApifyWalmartService.swift` for you
   - Just add API token
   - Start validating receipts

4. **Affordable scaling**
   - $49/month for moderate usage
   - Good for indie/startup
   - Can always upgrade to Oxylabs later

### Example Cost:

**Scenario**: Validating 20-item Walmart receipts

| Volume | Apify Cost | Oxylabs Cost |
|--------|------------|--------------|
| 10 receipts (200 items) | **$0** (free tier) | $49/month minimum |
| 100 receipts (2,000 items) | **$20/month** | $52/month ($49 + $3) |
| 1,000 receipts (20,000 items) | **$200/month** | $79/month ($49 + $30) |

At scale (1000+ receipts/month), Oxylabs becomes cheaper. But for starting out, Apify is better.

---

## Alternative: Oxylabs If...

Choose Oxylabs instead if:

1. **You need multi-retailer support NOW**
   - Validating Walmart, Target, Costco, etc.
   - Oxylabs E-Commerce API supports all major retailers
   - Apify needs separate actor for each

2. **You have budget**
   - $100+/month is no problem
   - Want best-in-class reliability
   - Enterprise support matters

3. **You need speed**
   - Sub-second response times critical
   - Processing thousands of receipts/day
   - Apify's 2-5 second latency is too slow

4. **You're building a business**
   - This is a commercial product
   - Need SLA guarantees
   - Can't risk downtime

---

## Quick Start with Apify

### 1. Sign Up (5 minutes)
- Go to https://apify.com/
- Create free account
- Get API token
- $5 free credit

### 2. Find Walmart Actor
Popular options:
- `junglee/walmart-scraper` (community favorite)
- `epctex/walmart-scraper` (well-maintained)
- Search "walmart" in Apify store

### 3. Test It
```bash
curl -X POST https://api.apify.com/v2/acts/junglee~walmart-scraper/runs \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "startUrls": [{"url": "https://www.walmart.com/search?q=012000161292"}],
    "maxItems": 1
  }'
```

### 4. Integrate
Use the `ApifyWalmartService.swift` I created:

```swift
let service = ApifyWalmartService()

// Search by UPC (solves "Seagrams" problem!)
let product = try await service.searchByUPC("012000161292")
print("Found: \(product.name)")
print("Price: $\(product.price)")

// Validate receipt
let result = try await service.validateReceiptItem(receiptItem)
if result.status == .possibleOvercharge {
    print("⚠️ Overcharge detected!")
}
```

---

## Bottom Line

For **Walmart receipt validation with UPC codes**:

### Start with Apify:
✅ Free to test  
✅ Solves your problem  
✅ Easy to integrate  
✅ Code ready to go  

### Upgrade to Oxylabs later if:
- You need multi-retailer  
- Volume justifies cost  
- Need enterprise features  

**I've already written the Apify integration for you** - just add your API token and test it!

Want to try it?
