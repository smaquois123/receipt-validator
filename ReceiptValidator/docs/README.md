# Receipt Validator

An iOS app that scans receipts using OCR (Optical Character Recognition) and compares item prices with current online prices from retailers to help you identify savings opportunities.

![iOS](https://img.shields.io/badge/iOS-17.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## Overview
Receipt Validator helps you track your purchases and identify potential savings by comparing receipt prices with current online prices from major retailers.

## ✨ Features

- 📸 **Receipt Scanning**: Capture receipts using your camera or import from photo library
- 🔍 **OCR Text Extraction**: Automatic text recognition using Apple's Vision framework
- 💾 **Data Persistence**: Store receipts and items using SwiftData
- 💰 **Price Comparison**: Compare receipt prices with current online prices
- 📊 **Savings Summary**: Track how much you could save
- 🏪 **Multi-Retailer Support**: Check prices across different retailers

## 🛠️ Tech Stack

- **SwiftUI**: Modern declarative UI framework
- **SwiftData**: Persistent data storage
- **Vision Framework**: OCR text recognition
- **AVFoundation**: Camera integration
- **URLSession**: Network requests for price checking

## 📋 Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## 🚀 Getting Started

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/receipt-validator.git
   cd receipt-validator
   ```

2. Open the project in Xcode:
   ```bash
   open ReceiptValidator.xcodeproj
   ```

3. Build and run the project (⌘ + R)

### Configuration

#### Info.plist Permissions
The app requires camera and photo library access. These are already configured in the project:

- `NSCameraUsageDescription`: "We need access to your camera to scan receipts"
- `NSPhotoLibraryUsageDescription`: "We need access to your photo library to import receipt images"

#### API Keys (Optional)
If you want to use the Walmart API or other price comparison services:

1. Create a `Secrets.swift` file in the project root (this file is gitignored)
2. Add your API keys:
   ```swift
   enum Secrets {
       static let walmartAPIKey = "YOUR_API_KEY_HERE"
   }
   ```

See [API Setup Guide](#-api-setup) below for more details.

## 📱 Usage

1. **Scan a Receipt**: Tap the "+" button and choose to take a photo or select from library
2. **Review Items**: The app will automatically extract items and prices using OCR
3. **Edit if Needed**: Adjust any incorrectly recognized items or prices
4. **Save**: Store the receipt for future reference
5. **Compare Prices**: View price comparisons with current online prices (if API configured)

## 🏗️ Project Structure

```
ReceiptValidator/
├── Models/
│   ├── Receipt.swift          # SwiftData model for receipts
│   └── ReceiptItem.swift      # SwiftData model for items
├── Services/
│   ├── ReceiptScannerService.swift    # Vision OCR processing
│   ├── PriceComparisonService.swift   # Price checking logic
│   ├── WalmartAPIService.swift        # Walmart API integration
│   └── ReceiptParser.swift            # Receipt text parsing
├── Views/
│   ├── ContentView.swift              # Receipt list
│   ├── ReceiptCaptureView.swift       # Camera/photo picker
│   ├── ReceiptReviewView.swift        # Edit scanned data
│   ├── ReceiptDetailView.swift        # View saved receipt
│   └── CameraView.swift               # Camera UI
└── ReceiptValidatorApp.swift          # App entry point
```

## 🔌 API Setup

The `PriceComparisonService` provides a framework for price checking. Here are your options:

### Option 1: Official Retailer APIs (Recommended)
- **Walmart API**: [developer.walmart.com](https://developer.walmart.com)
- **Best Buy API**: [developer.bestbuy.com](https://developer.bestbuy.com)
- **Target**: Partner APIs available

**Pros**: Legal, reliable, often free for reasonable usage

### Option 2: Third-Party Price Comparison Services
- **Rainforest API**: Amazon product data
- **Oxylabs**: E-commerce data
- **Diffbot**: Structured web data

**Pros**: Multi-retailer support, maintained infrastructure  
**Cons**: Paid services, rate limits

### Option 3: Manual Implementation
Implement your own price checking with proper rate limiting and ToS compliance.

⚠️ **Important**: Always respect retailer Terms of Service and implement appropriate rate limiting.

## 🧪 Testing

The app works best with:
- Clear, well-lit receipt photos
- Flat surface with minimal shadows
- Receipt fully visible in frame
- High contrast backgrounds

## 🗺️ Roadmap

- [ ] Barcode/UPC scanning for precise product matching
- [ ] Receipt categorization (groceries, electronics, etc.)
- [ ] Price alerts when items drop below receipt price
- [ ] Spending analytics and insights
- [ ] Export to PDF/CSV
- [ ] Multi-currency support
- [ ] Budget tracking integration
- [ ] ML improvements for better item matching

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## ⚖️ Legal Considerations

- Respect retailer Terms of Service
- Implement appropriate rate limiting
- Be transparent about data usage
- Consider privacy of receipt data
- Consult legal counsel before deploying price scraping at scale

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👤 Author

Created by JC Smith

## 🙏 Acknowledgments

- Apple's Vision framework for OCR capabilities
- SwiftUI and SwiftData for modern iOS development
- The iOS developer community

---

**Note**: This app is for educational and personal use. Price comparison features require additional API configuration.

