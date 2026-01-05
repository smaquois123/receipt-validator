# Quick XCConfig Verification Checklist

Use this checklist to verify your Config.xcconfig setup is working.

## ✅ Quick Verification Steps

### 1. Check XCConfig File Assignment (30 seconds)
- [ ] Open project (blue icon) in Xcode
- [ ] Click "Info" tab
- [ ] Under "Configurations", verify Config.xcconfig is assigned to Debug/Release

### 2. Add Info.plist Entry (1 minute)
- [ ] Select your **target** (not project)
- [ ] Go to "Info" tab  
- [ ] Click "+" button
- [ ] Add: `FIRE_CRAWL_API_KEY` = `$(FIRE_CRAWL_API_KEY)`

### 3. Build and Run (1 minute)
- [ ] Clean Build Folder: ⇧⌘K
- [ ] Build: ⌘B
- [ ] Run: ⌘R
- [ ] Check Xcode console for output

### 4. Check Console Output

**Expected (Success):**
```
🔑 FireCrawl API Key configured: ✅ YES
🔑 Key preview: fc-1389d79...
```

**If Failed:**
```
🔑 FireCrawl API Key configured: ❌ NO
⚠️ FireCrawl API key not configured...
```

## 🔧 Optional: Use Test View

For detailed diagnostics:

1. **Add to ContentView.swift** or any view:
```swift
NavigationLink("🔧 Test Configuration") {
    ConfigurationTestView()
}
```

2. **Or temporarily replace main view** in ReceiptValidatorApp.swift:
```swift
var body: some Scene {
    WindowGroup {
        ConfigurationTestView()  // Instead of ContentView()
    }
    .modelContainer(sharedModelContainer)
}
```

3. Run app and review diagnostics

## 🐛 Quick Troubleshooting

| Issue | Solution |
|-------|----------|
| "None" in Configurations | Drag Config.xcconfig to project, then assign in Project > Info |
| Key shows as `$(FIRE_CRAWL_API_KEY)` | XCConfig not applied; check step 1, clean build |
| Empty string returned | Missing Info.plist entry; check step 2 |
| Build error | Check Config.xcconfig syntax (no quotes, no semicolons) |

## 📁 Files Created for You

1. **XCCONFIG_SETUP_VERIFICATION.md** - Complete detailed guide
2. **ConfigurationTestView.swift** - Diagnostic UI view
3. **Config.xcconfig.template** - Template for team sharing
4. **This checklist** - Quick reference

## 🎯 What Should Happen

When properly configured:

1. **At compile time**: Xcode reads `Config.xcconfig`
2. **During build**: Xcode substitutes `$(FIRE_CRAWL_API_KEY)` in Info.plist
3. **At runtime**: Your app reads from Info.plist via `Bundle.main`
4. **Result**: API key is available to `AppConfiguration.FireCrawlApiKey`

## 🔒 Security Note

Your Config.xcconfig currently contains the actual API key. Before committing to git:

```bash
# Add to .gitignore
echo "Config.xcconfig" >> .gitignore
echo "FireCrawlApi.plist" >> .gitignore

# Commit the template instead
git add Config.xcconfig.template
git commit -m "Add config template"
```

## 📞 Still Having Issues?

Run the app and check:
1. Console output from ReceiptValidatorApp init
2. ConfigurationTestView diagnostic results
3. See detailed troubleshooting in XCCONFIG_SETUP_VERIFICATION.md

---

**TL;DR**: Assign xcconfig in project settings → Add key to Info.plist → Clean build → Run → Check console
