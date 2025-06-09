#!/bin/bash

# Regenerate Xcode project after VS Code edits
# Usage: ./regenerate_project.sh

echo "🔄 Regenerating Xcode project..."
xcodegen generate

if [ $? -eq 0 ]; then
    echo "✅ Project regenerated successfully!"
    echo "🚀 You can now build and run in Xcode simulator"
else
    echo "❌ Project regeneration failed"
    exit 1
fi
