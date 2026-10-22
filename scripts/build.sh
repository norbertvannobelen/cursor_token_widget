#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild \
  -project CursorTokenWidget.xcodeproj \
  -scheme CursorTokenWidget \
  -configuration Debug \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath build/DerivedData \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  build
