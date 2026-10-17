#!/bin/bash
set -euo pipefail

# Respect DEVELOPER_DIR, including local Xcode 27.1 RC. Never change xcode-select.
xcodebuild -version
xcrun --sdk iphonesimulator --show-sdk-version
xcodegen generate

if [ -z "${FOLDCHECK_SIMULATOR_ID:-}" ]; then
  FOLDCHECK_SIMULATOR_ID="$(xcrun simctl list devices available --json | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
for runtime in sorted(devices, reverse=True):
    for device in devices[runtime]:
        # Full UI suite assumes an ordinary, camera-free Face ID iPhone. Mock hinge
        # signals cover fold logic; they do not claim to resize the physical window.
        if device["name"] in ("iPhone 17", "iPhone 17 Pro"):
            print(device["udid"])
            sys.exit(0)
sys.exit("No available iPhone 17 simulator. Install an iOS runtime before running CI.")
')"
fi

mkdir -p TestResults
# A missing StoreKit product fails the purchase suite; it must not silently skip.
# Keep XCTest results/screenshots/coverage, but omit verbose system diagnostics: the RC
# can spend ten minutes collecting a simctl sysdiagnose even after successful tests.
xcodebuild test -project FoldCheck.xcodeproj -scheme FoldCheck -testPlan FoldCheck \
  -destination "platform=iOS Simulator,id=$FOLDCHECK_SIMULATOR_ID" \
  -derivedDataPath "${FOLDCHECK_DERIVED_DATA:-DerivedData/CI}" \
  -resultBundlePath "${FOLDCHECK_RESULT_BUNDLE:-TestResults/CI.xcresult}" \
  -parallel-testing-enabled NO -test-timeouts-enabled YES -collect-test-diagnostics never \
  -default-test-execution-time-allowance 180 -maximum-test-execution-time-allowance 300 \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES

xcodebuild build -project FoldCheck.xcodeproj -scheme FoldCheck -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "${FOLDCHECK_DERIVED_DATA:-DerivedData/CI}" CODE_SIGNING_ALLOWED=NO
