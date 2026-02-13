#!/bin/bash
set -euo pipefail

CRASHLYTICS_RUN=""

# Try common SwiftPM checkout locations in order of preference.
for CHECKOUTS_DIR in \
  "${SOURCE_PACKAGES_CHECKOUTS_DIR:-}" \
  "${CLONED_SOURCE_PACKAGES_DIR_PATH:-}/checkouts" \
  "${SOURCE_PACKAGES_DIR:-}/checkouts" \
  "${RUNNER_TEMP:-}/spm/checkouts" \
  "${BUILD_DIR%/Build/*}/SourcePackages/checkouts"; do
  if [[ -n "$CHECKOUTS_DIR" ]]; then
    CANDIDATE="${CHECKOUTS_DIR}/firebase-ios-sdk/Crashlytics/run"
    if [[ -f "$CANDIDATE" ]]; then
      CRASHLYTICS_RUN="$CANDIDATE"
      break
    fi
  fi
done

if [[ -z "$CRASHLYTICS_RUN" ]]; then
  echo "error: Crashlytics run script not found. Checked:"
  echo "  SOURCE_PACKAGES_CHECKOUTS_DIR=${SOURCE_PACKAGES_CHECKOUTS_DIR:-}"
  echo "  CLONED_SOURCE_PACKAGES_DIR_PATH=${CLONED_SOURCE_PACKAGES_DIR_PATH:-}"
  echo "  SOURCE_PACKAGES_DIR=${SOURCE_PACKAGES_DIR:-}"
  echo "  RUNNER_TEMP=${RUNNER_TEMP:-}"
  echo "  BUILD_DIR=${BUILD_DIR:-}"
  exit 1
fi

"$CRASHLYTICS_RUN"
