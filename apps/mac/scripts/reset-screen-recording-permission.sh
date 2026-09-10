#!/bin/zsh
set -euo pipefail

BUNDLE_ID="${1:-com.scap.Scap}"

/usr/bin/tccutil reset ScreenCapture "$BUNDLE_ID"

cat <<EOF
Reset Screen Recording permission for $BUNDLE_ID.

Next steps:
1. Quit Scap.
2. Run Scap from Xcode again.
3. Open System Settings when macOS asks.
4. Enable Scap in Privacy & Security > Screen & System Audio Recording.
5. Quit and run Scap once more.
EOF
