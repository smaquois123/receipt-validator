# Contributing to Receipt Validator

Thank you for considering contributing to Receipt Validator! This document provides guidelines and instructions for contributing.

## Code of Conduct

- Be respectful and inclusive
- Welcome newcomers and help them get started
- Focus on constructive feedback
- Keep discussions professional and on-topic

## How Can I Contribute?

### Reporting Bugs

Before submitting a bug report:
- Check the existing issues to avoid duplicates
- Test with the latest version of the app
- Collect information about your environment (iOS version, device model)

When submitting a bug report, include:
- Clear, descriptive title
- Steps to reproduce the issue
- Expected vs actual behavior
- Screenshots if applicable
- iOS version and device information

### Suggesting Enhancements

Enhancement suggestions are welcome! Please include:
- Clear description of the feature
- Use cases and benefits
- Potential implementation approach (if you have ideas)
- Mockups or examples (if applicable)

### Pull Requests

1. **Fork the repository** and create your branch from `main`
2. **Write clear commit messages** describing your changes
3. **Follow the existing code style**:
   - Use Swift naming conventions
   - Keep functions focused and small
   - Add comments for complex logic
   - Use SwiftUI best practices
4. **Test your changes** thoroughly
5. **Update documentation** if needed
6. **Submit the pull request** with a clear description

## Development Setup

1. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/receipt-validator.git
   ```

2. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. Make your changes and commit:
   ```bash
   git add .
   git commit -m "Add feature: description"
   ```

4. Push to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```

5. Open a Pull Request on GitHub

## Code Style Guidelines

### Swift Code Style

- Use 4 spaces for indentation (not tabs)
- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Prefer `let` over `var` when possible
- Use guard statements for early returns
- Keep line length under 120 characters when practical

### SwiftUI Best Practices

- Break complex views into smaller, reusable components
- Use view models for business logic when appropriate
- Keep views declarative and side-effect free
- Use proper SwiftData patterns for persistence
- Handle errors gracefully with user-friendly messages

### Comments

- Write self-documenting code when possible
- Add comments for complex algorithms or business logic
- Use `// MARK:` to organize code sections
- Document public APIs with documentation comments

Example:
```swift
/// Scans a receipt image and extracts text using OCR
/// - Parameter image: The receipt image to process
/// - Returns: An array of recognized text strings
/// - Throws: `ScanError` if OCR processing fails
func scanReceipt(_ image: UIImage) async throws -> [String] {
    // Implementation
}
```

## Testing

- Test your changes on real devices when possible
- Verify camera and photo library functionality
- Test with various receipt formats and qualities
- Ensure SwiftData persistence works correctly
- Check for memory leaks in image processing

## Areas Where Contributions Are Especially Welcome

- **OCR Accuracy**: Improving receipt text recognition
- **Price Comparison**: Adding support for more retailers
- **UI/UX**: Enhancing the user interface and experience
- **Testing**: Adding unit and integration tests
- **Documentation**: Improving guides and examples
- **Accessibility**: Making the app more accessible
- **Localization**: Adding support for more languages
- **Performance**: Optimizing image processing and data storage

## Questions?

Feel free to open an issue with your question, and we'll do our best to help!

## Recognition

Contributors will be acknowledged in the project. Thank you for helping make Receipt Validator better!
