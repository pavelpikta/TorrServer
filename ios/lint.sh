#!/bin/bash
# Lint the iOS sample project (Info.plist, xcodebuild analyze, optional SwiftLint).
# Usage:
#   ./ios/lint.sh
# Requires dist/TorrServerKit.xcframework (run ./ios/build.sh first).

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ios/lint.sh must run on macOS with Xcode" >&2
  exit 1
fi

IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${IOS_DIR}/.." && pwd)"
KIT="${ROOT}/dist/TorrServerKit.xcframework"
SAMPLE="${IOS_DIR}/TorrServerKitSample"
PROJECT="${SAMPLE}/TorrServerKitSample.xcodeproj"
SCHEME="TorrServerKitSample"
DESTINATION="${DESTINATION:-generic/platform=iOS Simulator}"
FAILED=0

if [[ ! -d "${KIT}" ]]; then
  echo "Missing ${KIT} — run ./ios/build.sh first" >&2
  exit 1
fi

echo "=== plutil Info.plist ==="
if ! plutil -lint "${SAMPLE}/TorrServerKitSample/Info.plist"; then
  FAILED=1
fi

echo "=== xcodebuild -list ==="
if ! xcodebuild -project "${PROJECT}" -list >/dev/null; then
  echo "xcodebuild could not load ${PROJECT}" >&2
  FAILED=1
fi

echo "=== xcodebuild analyze (warnings as errors) ==="
if ! xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration Debug \
  -destination "${DESTINATION}" \
  -derivedDataPath "${IOS_DIR}/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  analyze; then
  FAILED=1
fi

if command -v swiftlint >/dev/null 2>&1; then
  echo "=== SwiftLint ==="
  if ! swiftlint lint --strict --path "${SAMPLE}/TorrServerKitSample"; then
    FAILED=1
  fi
else
  echo "=== SwiftLint skipped (not installed) ==="
fi

if [[ "${FAILED}" -ne 0 ]]; then
  echo "ios/lint.sh failed" >&2
  exit 1
fi

echo "Done: iOS lint OK"
