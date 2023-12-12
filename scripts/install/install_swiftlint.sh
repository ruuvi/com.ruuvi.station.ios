#!/bin/sh

set -e

OUTPUT_DIR=".tools/swiftlint"


EXPECTED_SWIFTLINT_HASH="1511431b2ca803ecb921cfa119b70bb1"

# check if swiftlint is already installed by hashing all files in the output directory
if [ -d "$OUTPUT_DIR" ] && [ "$(find "$OUTPUT_DIR" -type f -exec md5 {} \; | md5)" = $EXPECTED_SWIFTLINT_HASH ]; then
  echo "swiftlint is already installed"
  exit 0
fi

# remove the output directory if it exists
if [ -d "$OUTPUT_DIR" ]; then
  rm -rf "$OUTPUT_DIR"
fi

# create the output directory
mkdir -p "$OUTPUT_DIR"

# download the latest release of swiftlint
curl -L "https://github.com/realm/SwiftLint/releases/download/0.54.0/portable_swiftlint.zip" -o ".tools/swiftlint.zip"

# unzip the downloaded file
unzip ".tools/swiftlint.zip" -d ".tools/swiftlint"

# remove the downloaded file
rm ".tools/swiftlint.zip"

# if the hash of downloaded swiftlint is not the expected value, exit with an error
INSTALLED_SWIFTLINT_HASH="$(find "$OUTPUT_DIR" -type f -exec md5 {} \; | md5)"
if [ "$INSTALLED_SWIFTLINT_HASH" != "$EXPECTED_SWIFTLINT_HASH" ]; then
  echo "swiftlint failed to install"
  echo "Expected hash: $EXPECTED_SWIFTLINT_HASH"
  echo "Actual hash: $INSTALLED_SWIFTLINT_HASH"
  exit 1
else
    echo "No swiftlint install needed" 
fi 