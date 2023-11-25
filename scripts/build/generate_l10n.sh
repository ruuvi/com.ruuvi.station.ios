#!/bin/sh

# if ./tools/swiftgen/bin/swiftgen not exists, install it
if [ ! -f "$PROJECT_DIR"/.tools/swiftgen/bin/swiftgen ]; then
    echo "Installing swiftgen..."
    "$PROJECT_DIR"/scripts/install/install_swiftgen.sh
fi

# execute swiftgen
"$PROJECT_DIR"/.tools/swiftgen/bin/swiftgen