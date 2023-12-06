#!/bin/sh

# immediately exit if any command has a non-zero exit status
set -e

OUTPUT_DIR=".tools/xcodegen"

EXPECTED_XCODEGEN_HASH="2566750f11478c88c2c114a120d7d7fc"

# check if xcodegen is already installed by hashing all files in the output directory
if [ -d "$OUTPUT_DIR" ] && [ "$(find "$OUTPUT_DIR" -type f -exec md5 {} \; | md5)" = $EXPECTED_XCODEGEN_HASH ]; then
  echo "xcodegen is already installed"
  exit 0
fi

# remove the output directory if it exists
if [ -d "$OUTPUT_DIR" ]; then
  rm -rf "$OUTPUT_DIR"
fi

# create the output directory
mkdir -p "$OUTPUT_DIR"

# download the latest release of xcodegen
curl -L "https://github.com/yonaskolb/XcodeGen/releases/download/2.38.0/xcodegen.zip" -o ".tools/xcodegen.zip"

# unzip the downloaded file
unzip ".tools/xcodegen.zip" -d ".tools"

# remove the downloaded file
rm ".tools/xcodegen.zip"

# if the hash of downloaded xcodegen is not the expected value, exit with an error
INSTALLED_XCODEGEN_HASH="$(find "$OUTPUT_DIR" -type f -exec md5 {} \; | md5)"
if [ "$INSTALLED_XCODEGEN_HASH" != "$EXPECTED_XCODEGEN_HASH" ]; then
  echo "xcodegen failed to install"
  echo "Expected hash: $EXPECTED_XCODEGEN_HASH"
  echo "Actual hash: $INSTALLED_XCODEGEN_HASH"
  exit 1
else
    echo "No xcodegen install needed" 
fi 