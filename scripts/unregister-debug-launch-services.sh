#!/bin/bash
# Xcode registers every built .app with Launch Services (Accessibility / Spotlight
# pickers then show a separate "Debug" entry). Undo that for Debug builds only.
set -euo pipefail

if [ "${CONFIGURATION:-}" != "Debug" ]; then
  exit 0
fi

APP="${TARGET_BUILD_DIR}/${FULL_PRODUCT_NAME}"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"

if [ -d "${APP}" ]; then
  "${LSREGISTER}" -f -u "${APP}" 2>/dev/null || true
fi

UPDATER="${APP}/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app"
if [ -d "${UPDATER}" ]; then
  "${LSREGISTER}" -f -u "${UPDATER}" 2>/dev/null || true
fi
