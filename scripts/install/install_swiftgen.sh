#!/bin/sh

set -e

OUTPUT_DIR=".tools/swiftgen"


EXPECTED_SWIFTGEN_HASH="6cd7a4c789050045970291a23d5232fe"

# check if swiftgen is already installed by hashing all files in the output directory
if [ -d "$OUTPUT_DIR" ] && [ "$(find "$OUTPUT_DIR" -type f -exec md5 {} \; | md5)" = $EXPECTED_SWIFTGEN_HASH ]; then
  echo "swiftgen is already installed"
  exit 0
fi

# remove the output directory if it exists
if [ -d "$OUTPUT_DIR" ]; then
  rm -rf "$OUTPUT_DIR"
fi

# create the output directory
mkdir -p "$OUTPUT_DIR"

# download the latest release of swiftgen
curl -L "https://github.com/SwiftGen/SwiftGen/releases/download/6.6.2/swiftgen-6.6.2.zip" -o ".tools/swiftgen.zip"

# unzip the downloaded file
unzip ".tools/swiftgen.zip" -d ".tools/swiftgen"

# remove the downloaded file
rm ".tools/swiftgen.zip"

# if the hash of downloaded swiftgen is not the expected value, exit with an error
INSTALLED_SWIFTGEN_HASH="$(find "$OUTPUT_DIR" -type f -exec md5 {} \; | md5)"
if [ "$INSTALLED_SWIFTGEN_HASH" != "$EXPECTED_SWIFTGEN_HASH" ]; then
  echo "swiftgen failed to install"
  echo "Expected hash: $EXPECTED_SWIFTGEN_HASH"
  echo "Actual hash: $INSTALLED_SWIFTGEN_HASH"
  exit 1
else
    echo "No swiftgen install needed" 
fi 