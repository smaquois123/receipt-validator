# API Setup Guide

This guide will help you set up API keys for price comparison features.

## Why API Keys Are Not Included

API keys are sensitive credentials that should never be committed to version control. Each developer needs to obtain their own API keys from the respective services.

## Setting Up Secrets

### Step 1: Create a Secrets.swift File

Create a new Swift file named `Secrets.swift` in your project (this file is already in `.gitignore`):

```swift
//
//  Secrets.swift
//  ReceiptValidator
//
//  DO NOT COMMIT THIS FILE TO GIT
//

import Foundation

enum Secrets {
    // Walmart API
    static let walmartAPIKey = "YOUR_WALMART_API_KEY_HERE"
    static let walmartAPISecret = "YOUR_WALMART_API_SECRET_HERE"
    
    // Add other API keys as needed
    // static let bestBuyAPIKey = "YOUR_BESTBUY_API_KEY_HERE"
}
```

### Step 2: Add Secrets.swift to .gitignore

This is already done! The `.gitignore` file includes:
```
Secrets.swift
APIKeys.swift
```

## Obtaining API Keys

### Walmart API

1. Visit [Walmart Developer Portal](https://developer.walmart.com)
2. Create an account or sign in
3. Register a new application
4. Copy your API Key and Secret
5. Add them to your `Secrets.swift` file

### Best Buy API

1. Visit [Best Buy Developer Portal](https://developer.bestbuy.com)
2. Register for an API key
3. Read their rate limits and terms of service
4. Add the key to your `Secrets.swift` file

### Third-Party Services

#### Rainforest API (Amazon)
- Website: https://www.rainforestapi.com
- Offers: Amazon product search and pricing
- Pricing: Pay-per-request model

#### Oxylabs
- Website: https://oxylabs.io
- Offers: E-commerce data from multiple retailers
- Pricing: Subscription-based

## Using API Keys in Your Code

### Import Your Secrets

In any service file where you need API keys:

```swift
// At the top of your service file
let apiKey = Secrets.walmartAPIKey
```

### Example: Walmart API Service

```swift
import Foundation

class WalmartAPIService {
    private let apiKey = Secrets.walmartAPIKey
    private let baseURL = "https://developer.api.walmart.com/api-proxy/service"
    
    func searchProduct(query: String) async throws -> [Product] {
        // Implementation using apiKey
    }
}
```

## Security Best Practices

### Do
✅ Store API keys in `Secrets.swift` (gitignored)  
✅ Use environment variables for production deployments  
✅ Implement rate limiting to avoid hitting API quotas  
✅ Cache API responses to minimize requests  
✅ Read and follow each API's terms of service  

### Don't
❌ Commit API keys to version control  
❌ Share your API keys publicly  
❌ Hardcode API keys directly in service files  
❌ Exceed rate limits  
❌ Use API keys in client-side code that can be decompiled  

## Alternative: Config Files

For team projects, you might use an `.xcconfig` file:

### Create Config.xcconfig

```
// Config.xcconfig
WALMART_API_KEY = your_key_here
```

Add to `.gitignore`:
```
*.xcconfig
Config.xcconfig
```

Then reference in your Info.plist and read in code.

## Testing Without API Keys

The app will still function without API keys! Features that work without APIs:
- Receipt scanning
- OCR text extraction
- Manual item entry
- Receipt storage and history
- Manual price comparison

Price comparison features will simply show placeholder data or be disabled until API keys are configured.

## Rate Limiting

Always implement rate limiting to respect API terms:

```swift
actor RateLimiter {
    private var lastRequestTime = Date.distantPast
    private let minimumInterval: TimeInterval = 1.0 // 1 second between requests
    
    func waitIfNeeded() async {
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(lastRequestTime)
        
        if timeSinceLastRequest < minimumInterval {
            let waitTime = minimumInterval - timeSinceLastRequest
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
        
        lastRequestTime = Date()
    }
}
```

## Need Help?

If you have questions about API setup, please open an issue on GitHub or refer to the documentation for each API service.
