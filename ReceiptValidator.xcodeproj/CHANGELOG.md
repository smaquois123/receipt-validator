# Changelog

All notable changes to Receipt Validator will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of Receipt Validator
- Receipt scanning with camera and photo library support
- OCR text extraction using Vision framework
- Automatic parsing of items and prices from receipts
- SwiftData persistence for receipts and items
- Receipt image storage
- Price comparison framework (requires API configuration)
- Support for Walmart API integration
- Receipt detail view with item breakdown
- Edit capability for scanned receipt data
- Basic price difference calculation

### Known Issues
- Price comparison requires API key configuration
- OCR accuracy depends on receipt quality and lighting
- Some receipt formats may require manual correction

## [0.1.0] - 2025-12-23

### Added
- Initial project structure
- Core models (Receipt, ReceiptItem)
- Basic UI views
- Camera integration
- OCR service implementation

---

## How to Update This File

When adding new features or fixes:

### Added
- For new features

### Changed
- For changes in existing functionality

### Deprecated
- For soon-to-be removed features

### Removed
- For now removed features

### Fixed
- For any bug fixes

### Security
- For vulnerability fixes
