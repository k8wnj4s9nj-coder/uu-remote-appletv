#!/usr/bin/env bash
# Optional: pre-download LiveKit WebRTC xcframework for offline Mac builds.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/Vendor/LiveKitWebRTC.xcframework.zip"
VER="${1:-150.7871.03}"
URL="https://github.com/livekit/webrtc-xcframework/releases/download/${VER}/LiveKitWebRTC.xcframework.zip"
mkdir -p "$ROOT/Vendor"
echo "Downloading $URL"
curl -L --fail -o "$DEST" "$URL"
echo "Saved $DEST ($(du -h "$DEST" | awk '{print $1}'))"
echo "On Mac you can still prefer SPM; this zip is a fallback for binaryTarget(path:)."
