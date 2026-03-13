#!/bin/bash
# Release build script — Gallery 20.5 Staff App
# Usage:
#   ./build_release.sh apk      → Android APK
#   ./build_release.sh appbundle → Android App Bundle (Play Store)
#   ./build_release.sh ipa      → iOS IPA

SENTRY_DSN="https://87eed15dc4b2481c06fc245d5b46764c@o4511038365040640.ingest.us.sentry.io/4511038379524096"
DART_DEFINES="--dart-define=SENTRY_DSN=$SENTRY_DSN --dart-define=DART_ENV=production"

TARGET=${1:-apk}

echo "Building release $TARGET..."

case $TARGET in
  apk)
    flutter build apk --release $DART_DEFINES
    ;;
  appbundle)
    flutter build appbundle --release $DART_DEFINES
    ;;
  ipa)
    flutter build ipa --release $DART_DEFINES
    ;;
  *)
    echo "Unknown target: $TARGET"
    echo "Usage: ./build_release.sh [apk|appbundle|ipa]"
    exit 1
    ;;
esac

echo "Done."
