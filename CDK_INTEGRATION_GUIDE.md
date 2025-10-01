# CashuDevKit (CDK) Integration Guide for Signal iOS

## Overview
This guide explains how to integrate the CashuDevKit Swift package into the Signal iOS project, which uses both CocoaPods and Swift Package Manager.

## Current Status
✅ **Completed Steps:**
1. Added cdk-swift repository to the workspace
2. Resolved SPM cache issues
3. Added local package reference to Signal.xcworkspace
4. Verified package builds successfully
5. Created integration scaffold (CashuIntegration.swift)

## Next Steps in Xcode

### 1. Add CashuDevKit to Signal Target

1. Open `Signal.xcworkspace` in Xcode
2. In the project navigator, select the `Signal` project (blue icon)
3. Select the `Signal` target from the targets list
4. Go to the **General** tab
5. Scroll to **Frameworks, Libraries, and Embedded Content**
6. Click the **+** button
7. You should see `CashuDevKit` from the cdk-swift package - select it
8. Set the embedding option to **Do Not Embed** (since it's a static library)

### 2. Import and Use CashuDevKit

Once added to the target, you can import and use it in Swift files:

```swift
import CashuDevKit

// Example usage
let wallet = try CashuWallet(...)
```

### 3. Update CashuIntegration.swift

The file `/Signal/src/CashuIntegration.swift` has been created with a basic integration scaffold. After adding the dependency:

1. Uncomment the `import CashuDevKit` line
2. Implement the TODO methods using actual CashuDevKit APIs
3. Add any additional Cashu functionality needed

## Integration Architecture

### Coexistence with CocoaPods
- **CocoaPods**: Manages existing Signal dependencies (LibSignalClient, MobileCoin, etc.)
- **Swift Package Manager**: Manages CashuDevKit and any future Swift packages
- Both can coexist peacefully in the same workspace

### File Structure
```
Signal-iOS/
├── Podfile                 # CocoaPods dependencies
├── Signal.xcworkspace/     # Workspace containing both Pods and SPM packages
│   └── xcshareddata/
│       └── swiftpm/       # SPM configuration
├── Signal/
│   └── src/
│       └── CashuIntegration.swift  # Cashu integration code
└── ../cdk-swift/          # Local cdk-swift package
```

## Troubleshooting

### SPM Cache Issues
If you encounter "already exists in file system" errors:
```bash
rm -rf ~/Library/Caches/org.swift.swiftpm/artifacts/*
```

### Package Resolution
To manually resolve packages:
```bash
xcodebuild -resolvePackageDependencies -workspace Signal.xcworkspace -scheme Signal
```

### Binary Target Issues
The cdk-swift package includes a binary target (cdkFFI.xcframework). If you encounter issues:
1. Ensure you're using Xcode 13 or later
2. Check that the binary checksum matches in Package.swift
3. Clean build folder: Product → Clean Build Folder

## Testing the Integration

1. Build the Signal target to ensure CashuDevKit links correctly
2. Run the existing Signal test suite to ensure no regressions
3. Add unit tests for CashuIntegration functionality

## Additional Considerations

### UI Integration
Consider where Cashu functionality should appear in the Signal UI:
- Payment settings alongside MobileCoin?
- Separate Cashu wallet section?
- Integration with existing payment flows?

### Security
- Cashu wallet keys should be stored securely (Keychain)
- Consider using Signal's existing encryption infrastructure
- Audit token handling and transmission

### Network Configuration
- Configure mint URLs appropriately for production/staging
- Handle network errors gracefully
- Consider offline token management

## Resources
- [CashuDevKit Documentation](https://github.com/cashubtc/cdk-swift)
- [Cashu Protocol Specification](https://github.com/cashubtc/nuts)
- [Signal iOS Contributing Guide](https://github.com/signalapp/Signal-iOS/blob/main/CONTRIBUTING.md)
