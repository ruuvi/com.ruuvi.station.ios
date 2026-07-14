#!/bin/bash

set -euo pipefail

APP_BUNDLE="${TARGET_BUILD_DIR:-}/${WRAPPER_NAME:-}"

if [ -z "${TARGET_BUILD_DIR:-}" ] || [ -z "${WRAPPER_NAME:-}" ] || [ ! -d "$APP_BUNDLE" ]; then
    exit 0
fi

find "$APP_BUNDLE" -type d -name "ru.lproj" -prune -exec rm -rf {} +
