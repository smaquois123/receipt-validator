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
    
    /// FireCrawl API key for web scraping
    /// Sign up at: https://firecrawl.dev
    /// 
    /// IMPORTANT: In production, store this securely using:
    /// 1. Keychain for iOS
    /// 2. Environment variables
    /// 3. A secure configuration file not checked into git
    static let fireCrawlAPIKey: String = {
        // Check for environment variable first (useful for CI/CD)
        if let envKey = ProcessInfo.processInfo.environment["FIRECRAWL_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        
        // Check for a local configuration file (not in git)
        if let path = Bundle.main.path(forResource: "APIKeys", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
           let key = dict["FireCrawlAPIKey"] as? String {
            return key
        }
        
        // Default empty key (will need to be configured)
        return ""
    }()
    
    // MARK: - Feature Flags
    
    /// Enable/disable price validation feature
    static let enablePriceValidation = true
    
    /// Enable/disable price comparison feature
    static let enablePriceComparison = true
    
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
    /// Checks if FireCrawl API key is configured
    static var isFireCrawlConfigured: Bool {
        !fireCrawlAPIKey.isEmpty
    }
    
    /// Returns a user-friendly message if API key is missing
    static var configurationMessage: String {
        if !isFireCrawlConfigured {
            return """
            FireCrawl API key not configured.
            
            To enable price validation:
            1. Sign up at https://firecrawl.dev
            2. Get your API key
            3. Add it to APIKeys.plist or set FIRECRAWL_API_KEY environment variable
            """
        }
        return "Configuration OK"
    }
}
