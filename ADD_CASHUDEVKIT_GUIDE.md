# Step-by-Step Guide: Adding CashuDevKit to Signal Target

## Prerequisites
✅ Signal.xcworkspace is open in Xcode
✅ cdk-swift package is already added to workspace (this is done)

## Detailed Steps with Xcode UI

### Step 1: Navigate to Project Settings
1. In Xcode's left sidebar (Navigator), look for the **blue project icon** labeled "Signal"
2. Click on it (not the folders below it, but the top-level project icon)

### Step 2: Select the Signal Target
1. In the main editor area, you'll see:
   - Top section: PROJECT with "Signal"
   - Bottom section: TARGETS with multiple items
2. Under TARGETS, click on **"Signal"** (the one with the app icon)
   - ⚠️ NOT "SignalTests", "SignalShareExtension", or "SignalNSE"

### Step 3: Go to General Tab
1. At the top of the editor, you'll see tabs: General, Signing & Capabilities, Resource Tags, Info, Build Settings, Build Phases
2. Click on **"General"**

### Step 4: Find Frameworks Section
1. Scroll down past "Minimum Deployments", "Deployment Info"
2. Find the section: **"Frameworks, Libraries, and Embedded Content"**
3. You'll see a list of existing frameworks like:
   - Pods_Signal.framework
   - Maybe some system frameworks

### Step 5: Add CashuDevKit
1. Click the **"+"** button below the frameworks list
2. A sheet will pop up with available libraries
3. At the top of the sheet, you might see sections:
   - "cdk-swift Package" (this is what we want!)
   - "Workspace"
   - "iOS SDK"
4. Under "cdk-swift Package", select **"CashuDevKit"**
5. Click **"Add"**

### Step 6: Configure Embedding
1. After adding, CashuDevKit will appear in the list
2. On the right side, there's an "Embed" column
3. Click the dropdown and select **"Do Not Embed"**
   - This is important because CashuDevKit is a static library

## Alternative Method: If CashuDevKit Doesn't Appear

If you don't see "cdk-swift Package" in the framework picker:

### Option A: Try Build Phases
1. Go to **"Build Phases"** tab (next to General)
2. Expand **"Link Binary With Libraries"**
3. Click **"+"**
4. Search for "CashuDevKit"
5. Add it

### Option B: Re-resolve Packages
1. In Xcode menu bar: **File → Packages → Resolve Package Versions**
2. Wait for resolution
3. Try adding the framework again

### Option C: Clean and Retry
1. **Product → Clean Build Folder** (Shift+Cmd+K)
2. **File → Packages → Reset Package Caches**
3. Close and reopen Xcode
4. Try adding the framework again

## Verification

After adding CashuDevKit, verify it's working:

### 1. Check Project File
Run in terminal:
```bash
grep -q "CashuDevKit" Signal.xcodeproj/project.pbxproj && echo "✅ CashuDevKit linked" || echo "❌ Not linked"
```

### 2. Try Building
1. Select any iOS Simulator as destination
2. Press **Cmd+B** to build
3. If it builds without errors mentioning CashuDevKit, it's working!

### 3. Enable in Code
Once CashuDevKit is linked:
1. Open `Signal/src/CashuIntegration.swift`
2. Uncomment line 17: `// import CashuDevKit`
3. Remove or comment out the mock `CashuWallet` struct (lines 24-42)
4. Build again to verify

## Common Issues and Solutions

### Issue: "No such module 'CashuDevKit'"
**Solution**: CashuDevKit isn't properly linked. Follow the steps above again.

### Issue: CashuDevKit doesn't appear in framework picker
**Solution**: 
1. Make sure cdk-swift is in the workspace (check File Navigator)
2. Try File → Packages → Resolve Package Versions
3. Restart Xcode

### Issue: Build fails with undefined symbols
**Solution**: Make sure "Do Not Embed" is selected for CashuDevKit

### Issue: Package resolution fails
**Solution**:
1. Check internet connection
2. Clear SPM cache: `rm -rf ~/Library/Caches/org.swift.swiftpm`
3. In Xcode: File → Packages → Reset Package Caches

## Success Indicators

You know it's working when:
✅ CashuDevKit appears in "Frameworks, Libraries, and Embedded Content"
✅ Building succeeds without CashuDevKit errors
✅ `import CashuDevKit` works in Swift files
✅ You can use CashuDevKit types like `Wallet`, `Token`, etc.

## Next Steps After Linking

1. Update `CashuIntegration.swift` to use real CashuDevKit
2. Implement actual wallet operations
3. Test send/receive with real ecash tokens
4. Connect to a real Cashu mint

## Need Help?

If you encounter issues:
1. Check the build log for specific errors
2. Verify cdk-swift package is properly resolved
3. Ensure you're adding to the correct target (Signal, not SignalTests)
4. Try the verification script: `./verify_cashu_integration.sh`
