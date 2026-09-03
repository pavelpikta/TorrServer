#!/bin/bash
# Build the iOS sample app (and TorrServerKit.xcframework if missing).
# Usage:
#   ./ios/build.sh
#   FORCE_KIT=1 ./ios/build.sh          # rebuild the XCFramework first
#   DESTINATION='platform=iOS Simulator,name=iPhone 17' ./ios/build.sh

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ios/build.sh must run on macOS with Xcode" >&2
  exit 1
fi

IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${IOS_DIR}/.." && pwd)"
KIT="${ROOT}/dist/TorrServerKit.xcframework"
PROJECT="${IOS_DIR}/TorrServerKitSample/TorrServerKitSample.xcodeproj"
SCHEME="TorrServerKitSample"
CONFIGURATION="${CONFIGURATION:-Debug}"
DESTINATION="${DESTINATION:-generic/platform=iOS Simulator}"

if [[ "${FORCE_KIT:-0}" == "1" || ! -d "${KIT}" ]]; then
  echo "=== Building TorrServerKit.xcframework ==="
  "${ROOT}/build-ios.sh"
fi

if [[ ! -d "${KIT}" ]]; then
  echo "Missing ${KIT}" >&2
  exit 1
fi

echo "=== Building ${SCHEME} (${CONFIGURATION}) ==="
xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -destination "${DESTINATION}" \
  -derivedDataPath "${IOS_DIR}/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

echo "Done: ${SCHEME} ${CONFIGURATION}"
