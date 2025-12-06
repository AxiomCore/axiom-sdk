#!/bin/bash
set -e

echo "🧹 Cleaning Axiom runtime..."
rm -rf ios/axiom_runtime

echo "🧹 Removing Pods..."
rm -rf ios/Pods ios/Podfile.lock ios/Runner.xcworkspace

echo "🧹 Removing 'pod AxiomRuntime' from Podfile..."
sed -i '' '/pod '\''AxiomRuntime'\''/d' ios/Podfile

echo "🧹 Cleaning DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*

echo "✨ Clean reset completed!"
echo "➡️  You can now run: axiom pull"

