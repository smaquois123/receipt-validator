//
//  AppConfiguration.swift
//  ReceiptValidator
//
//  Created by JC Smith on 1/1/26.
//

import Foundation

/// Configuration for app-wide settings and API keys
struct AppConfiguration {
    
    // MARK: - API Keys
    
    /// Apify API Token (Primary validation service - supports UPC-based validation)
    /// Sign up at: https://apify.com/ (Free tier: $5 credit/month ~500 searches)
    /// Can search Walmart by UPC - solves the name matching problem!
    static let ApifyAPIToken: String = {
        return loadAPIKey(
            name: "APIFY_API_TOKEN",
            plistFile: "ScrapingAPIs",
            plistKey: "ApifyAPIToken"
        )
    }()
    
    // MARK: - UPC Lookup API Keys
    
    /// UPCItemDB API Key (Free tier: 100 requests/day)
    /// Sign up at: https://www.upcitemdb.com/
    static let UPCItemDBKey: String = {
        return loadAPIKey(
            name: "UPC_ITEM_DB_KEY",
            plistFile: "ScrapingAPIs",
            plistKey: "UPCItemDBKey"
        )
    }()
    
    /// Barcode Lookup API Key (Paid: $30/month for 500 requests/day)
    /// Sign up at: https://www.barcodelookup.com/api
    static let BarcodeLookupKey: String = {
        return loadAPIKey(
            name: "BARCODE_LOOKUP_KEY",
            plistFile: "ScrapingAPIs",
            plistKey: "BarcodeLookupKey"
        )
    }()
    
    /// UPC Database API Key (Free tier available)
    /// Sign up at: https://upcdatabase.org/
    static let UPCDatabaseKey: String = {
        return loadAPIKey(
            name: "UPC_DATABASE_KEY",
            plistFile: "ScrapingAPIs",
            plistKey: "UPCDatabaseKey"
        )
    }()
    
    /// Walmart API Key (Requires approval)
    /// Apply at: https://developer.walmart.com/
    static let WalmartAPIKey: String = {
        return loadAPIKey(
            name: "WALMART_API_KEY",
            plistFile: "ScrapingAPIs",
            plistKey: "WalmartAPIKey"
        )
    }()
    
    /// Dictionary of all UPC API keys for UPCLookupService
    static let upcAPIKeys: [String: String] = {
        var keys: [String: String] = [:]
        
        if !UPCItemDBKey.isEmpty {
            keys["upcItemDB"] = UPCItemDBKey
        }
        if !BarcodeLookupKey.isEmpty {
            keys["barcodeLookup"] = BarcodeLookupKey
        }
        if !UPCDatabaseKey.isEmpty {
            keys["upcDatabase"] = UPCDatabaseKey
        }
        if !WalmartAPIKey.isEmpty {
            keys["walmart"] = WalmartAPIKey
        }
        
        return keys
    }()
    
    // MARK: - Helper Method
    
    private static func loadAPIKey(name: String, plistFile: String, plistKey: String) -> String {
        // Check Info.plist for build-time configuration (from xcconfig)
        if let key = Bundle.main.object(forInfoDictionaryKey: name) as? String,
           !key.isEmpty,
           !key.hasPrefix("$") { // Check it's not an unresolved variable
            return key
        }
        
        // Check for environment variable (useful for CI/CD)
        if let envKey = ProcessInfo.processInfo.environment[name], !envKey.isEmpty {
            return envKey
        }
        
        // Check for a local configuration file (not in git)
        if let path = Bundle.main.path(forResource: plistFile, ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
           let key = dict[plistKey] as? String,
           !key.isEmpty {
            return key
        }
        
        // Return empty string if not configured
        return ""
    }
    
    // MARK: - Feature Flags
    
    /// Enable/disable price validation feature
    static let enablePriceValidation = true
    
    /// Enable/disable price comparison feature
    static let enablePriceComparison = true
    
    /// Prefer UPC lookup over name-based search when available
    /// UPC lookup is more accurate and often cheaper/faster
    static let preferUPCLookup = true
    
    /// Maximum number of concurrent validation requests
    static let maxConcurrentValidations = 3
    
    /// Timeout for network requests (in seconds)
    static let networkTimeout: TimeInterval = 30
    
    /// Delay between validation requests to avoid rate limiting (in seconds)
    static let validationDelay: TimeInterval = 1.0
    
    // MARK: - Validation Settings
    
    /// Price difference tolerance percentage (0.0 to 1.0)
    /// e.g., 0.1 = 10% tolerance
    static let priceTolerancePercentage: Double = 0.10
    
    /// Minimum confidence threshold for validation
    static let minimumConfidenceThreshold: Double = 0.5
    
    /// Cache duration for price checks (in seconds)
    static let priceCacheDuration: TimeInterval = 3600 // 1 hour
}

// MARK: - Helper Extensions

extension AppConfiguration {
    /// Checks if Apify API token is configured
    static var isApifyConfigured: Bool {
        !ApifyAPIToken.isEmpty
    }
    
    /// Checks if any UPC lookup service is configured
    static var isUPCLookupConfigured: Bool {
        !upcAPIKeys.isEmpty
    }
    
    /// Returns a user-friendly message if API key is missing
    static var configurationMessage: String {
        if !isApifyConfigured {
            return """
            Apify API token not configured.
            
            To enable price validation:
            1. Sign up at https://apify.com/
            2. Get your API token (Free tier: $5 credit/month)
            3. Add it using one of these methods:
               • Update APIFY_API_TOKEN in Config.xcconfig and add to Info.plist
               • Create ScrapingAPIs.plist with an 'ApifyAPIToken' string value
               • Set APIFY_API_TOKEN environment variable
            """
        }
        return "Configuration OK"
    }
}
