#!/bin/bash

echo "Verifying CashuDevKit Integration..."
echo "====================================="
echo ""

# Check if CashuDevKit is referenced in the project file
echo "1. Checking project.pbxproj for CashuDevKit references..."
if grep -q "CashuDevKit" Signal.xcodeproj/project.pbxproj; then
    echo "✅ CashuDevKit found in project file"
    echo ""
    echo "References found:"
    grep "CashuDevKit" Signal.xcodeproj/project.pbxproj | head -5
else
    echo "❌ CashuDevKit not found in project file"
    echo "   Please add CashuDevKit to the Signal target in Xcode"
fi

echo ""
echo "2. Checking if cdk-swift package is in workspace..."
if grep -q "cdk-swift" Signal.xcworkspace/contents.xcworkspacedata; then
    echo "✅ cdk-swift package is in workspace"
else
    echo "❌ cdk-swift package not in workspace"
fi

echo ""
echo "3. Build test (this will take a moment)..."
xcodebuild -workspace Signal.xcworkspace -scheme Signal -destination "generic/platform=iOS" -configuration Debug build-for-testing CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "(CashuDevKit|cashu|error:)" | head -10

echo ""
echo "====================================="
echo "Integration verification complete!"
echo ""
echo "Next steps if CashuDevKit is linked:"
echo "1. In CashuIntegration.swift, uncomment: import CashuDevKit"
echo "2. Remove the mock CashuWallet struct"
echo "3. Implement real CashuDevKit functionality"

