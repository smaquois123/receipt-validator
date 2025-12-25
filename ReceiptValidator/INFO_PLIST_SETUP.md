# Info.plist Configuration

Add these entries to your Info.plist file (right-click Info.plist > Open As > Source Code):

```xml
<key>NSCameraUsageDescription</key>
<string>We need access to your camera to scan receipt photos for price comparison</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to select receipt images for scanning</string>
```

Or add via Xcode UI:
1. Select your project in the navigator
2. Select your app target
3. Go to "Info" tab
4. Click the "+" button to add new entries:
   - Privacy - Camera Usage Description
   - Privacy - Photo Library Usage Description
