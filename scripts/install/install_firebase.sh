#!/bin/sh

set -e

OUTPUT_DIR=".tools/firebase"


EXPECTED_FIREBASE_HASH="9a1c3fb10726c370144f5ea6ca063664"

# check if firebase is already installed by hashing all files in the output directory
if [ -d "$OUTPUT_DIR" ] && [ "$(find "$OUTPUT_DIR" -type f -exec md5 {} \; | md5)" = $EXPECTED_FIREBASE_HASH ]; then
  echo "firebase is already installed"
  exit 0
fi

# remove the output directory if it exists
if [ -d "$OUTPUT_DIR" ]; then
  rm -rf "$OUTPUT_DIR"
fi

# create the output directory
mkdir -p "$OUTPUT_DIR"

# download the latest release of firebase
curl -o "$OUTPUT_DIR/firebase" -L --progress-bar "https://firebase.tools/bin/macos/v12.9.1"
chmod +x ./$OUTPUT_DIR/firebase

# if the hash of downloaded firebase is not the expected value, exit with an error
INSTALLED_FIREBASE_HASH="$(find "$OUTPUT_DIR" -type f -exec md5 {} \; | md5)"
if [ "$INSTALLED_FIREBASE_HASH" != "$EXPECTED_FIREBASE_HASH" ]; then
  echo "firebase failed to install"
  echo "Expected hash: $EXPECTED_FIREBASE_HASH"
  echo "Actual hash: $INSTALLED_FIREBASE_HASH"
  exit 1
else
    echo "No firebase install needed" 
fi 