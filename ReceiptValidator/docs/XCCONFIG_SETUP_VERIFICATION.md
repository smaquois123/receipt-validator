# XCConfig Setup Verification Guide

This guide will help you verify that your `Config.xcconfig` file is properly integrated with your Xcode project.

## Current Setup

You have:
- ✅ `Config.xcconfig` file with `FIRE_CRAWL_API_KEY = fc-1389d79e92cd4a6aa431cd081d5ea1fa`
- ✅ `ReceiptValidatorAppConfiguration.swift` updated to read from Info.plist

## Step-by-Step Verification

### Step 1: Verify XCConfig is Assigned to Build Configuration

1. **Open your project in Xcode**
2. **Select the project** (blue icon at top of navigator)
3. **Select the Project** (not the target) in the editor
4. **Click the "Info" tab**
5. **Look at the "Configurations" section**
   
   You should see:
   ```
   Debug   -> Config
   Release -> Config (or None)
   ```
   
   **If you see "None":**
   - Click on "None" next to Debug
   - Select "Config" from the dropdown
   - Repeat for Release if needed

### Step 2: Add API Key to Info.plist

You need to pass the xcconfig value into your app's Info.plist so it's accessible at runtime.

#### Option A: Using Xcode UI (Easier)

1. **Select your target** (not the project)
2. **Go to "Info" tab**
3. **Click the "+" button** under "Custom iOS Target Properties"
4. **Add new entry:**
   - Key: `FIRE_CRAWL_API_KEY`
   - Type: String
   - Value: `$(FIRE_CRAWL_API_KEY)`

#### Option B: Using Source Code (If you prefer editing XML)

1. **Find Info.plist in Project Navigator**
2. **Right-click > Open As > Source Code**
3. **Add this entry** anywhere between the main `<dict>` tags:

```xml
<key>FIRE_CRAWL_API_KEY</key>
<string>$(FIRE_CRAWL_API_KEY)</string>
```

The `$(FIRE_CRAWL_API_KEY)` syntax tells Xcode to replace this with the value from Config.xcconfig at build time.

### Step 3: Verify the Build Setting

1. **Select your target**
2. **Go to "Build Settings" tab**
3. **Make sure "All" and "Combined" are selected** (not "Basic")
4. **In the search box**, type: `FIRE_CRAWL_API_KEY`
5. **You should see:**
   - The setting name: `FIRE_CRAWL_API_KEY`
   - Value: `fc-1389d79e92cd4a6aa431cd081d5ea1fa`
   - Source should show it's from Config.xcconfig (might show in green/light color)

If you don't see it, the xcconfig might not be properly applied.

### Step 4: Clean and Rebuild

1. **Clean build folder**: Product menu > Clean Build Folder (⇧⌘K)
2. **Build the project**: Product menu > Build (⌘B)
3. **Check for errors in build log**

### Step 5: Test at Runtime

Add this code temporarily to your app to verify it's working:

```swift
// Add to ReceiptValidatorApp.swift in init() or .onAppear
init() {
    print("🔑 FireCrawl API Key loaded: \(AppConfiguration.isFireCrawlConfigured ? "✅ YES" : "❌ NO")")
    print("🔑 Key value (first 10 chars): \(String(AppConfiguration.FireCrawlApiKey.prefix(10)))")
    print("🔑 Configuration status: \(AppConfiguration.configurationMessage)")
}
```

Run the app and check the Xcode console output.

## Troubleshooting

### Issue: "None" shows in Configurations

**Solution**: Your xcconfig file might not be in the project properly.
1. Drag `Config.xcconfig` into your project in Xcode
2. When prompted, **DO NOT** check "Copy items if needed"
3. **DO check** "Add to targets" for your main app target
4. Then reassign it in Project > Info > Configurations

### Issue: Build setting doesn't show

**Solution**: The xcconfig file syntax might be wrong.
1. Open `Config.xcconfig` in Xcode
2. Verify it looks exactly like:
   ```
   FIRE_CRAWL_API_KEY = fc-1389d79e92cd4a6aa431cd081d5ea1fa
   ```
3. No quotes, no semicolons, no extra spaces at the end

### Issue: Info.plist shows literal "$(FIRE_CRAWL_API_KEY)" at runtime

**Solution**: The build setting isn't being processed.
1. Verify xcconfig is assigned (Step 1)
2. Clean build folder (⇧⌘K)
3. Delete derived data: `~/Library/Developer/Xcode/DerivedData/ReceiptValidator-*`
4. Restart Xcode
5. Build again

### Issue: Empty string returned

**Solutions**:
1. Check that Info.plist has the key (Step 2)
2. Verify the build setting exists (Step 3)
3. Make sure you're running on a simulator/device (not just building)
4. Check the console for the warning messages from AppConfiguration

## Alternative: Direct Plist Approach

If xcconfig continues to be problematic, you can use the simpler plist approach:

1. **Create a new file**: File > New > File
2. **Choose "Property List"**
3. **Name it**: `FireCrawlApi.plist`
4. **Add to target**: Check your app target
5. **Edit the plist**:
   - Right-click > Open As > Source Code
   - Replace contents with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>FireCrawlApiKey</key>
	<string>fc-1389d79e92cd4a6aa431cd081d5ea1fa</string>
</dict>
</plist>
```

6. **Add to .gitignore**:
```
FireCrawlApi.plist
```

The code already supports this fallback!

## Security Best Practices

⚠️ **Important**: Your API key is currently visible in Config.xcconfig. For a production app:

1. **Add Config.xcconfig to .gitignore**:
   ```
   Config.xcconfig
   FireCrawlApi.plist
   ```

2. **Create a template file** (checked into git):
   ```
   # Config.xcconfig.template
   # Copy this to Config.xcconfig and add your API key
   FIRE_CRAWL_API_KEY = YOUR_API_KEY_HERE
   ```

3. **For team collaboration**: Use environment variables or a secrets management service

4. **For production**: Consider using Keychain or a backend service to store/retrieve the key

## Expected Output

When everything is working correctly:
```
🔑 FireCrawl API Key loaded: ✅ YES
🔑 Key value (first 10 chars): fc-1389d79
🔑 Configuration status: Configuration OK
```

If not working:
```
🔑 FireCrawl API Key loaded: ❌ NO
🔑 Key value (first 10 chars): 
⚠️ API Key not loaded. Check that:
   1. Config.xcconfig is added to your build configuration
   2. Info.plist contains FIRE_CRAWL_API_KEY = $(FIRE_CRAWL_API_KEY)
   3. Or 'FireCrawlApi.plist' is in the app bundle
   4. Or FIRE_CRAWL_API_KEY environment variable is set
🔑 Configuration status: FireCrawl API key not configured...
```

## Need Help?

If you're still stuck:
1. Check the console output from the test code
2. Verify each step above
3. Try the alternative plist approach
4. Ensure you're building for a real target (not just checking syntax)
