#!/bin/bash

if which ./.tools/swiftlint/swiftlint > /dev/null; then
    ./.tools/swiftlint/swiftlint
else
    echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi