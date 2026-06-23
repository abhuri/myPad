#!/bin/bash
set -euo pipefail

APP_NAME="myPad"
VERSION="${1:-2.0.2}"
SIGN_IDENTITY="${MYPAD_SIGN_IDENTITY:--}"
NOTARY_PROFILE="${MYPAD_NOTARY_PROFILE:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/release"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
ZIP_PATH="$RELEASE_DIR/$APP_NAME-$VERSION.zip"
SHA_PATH="$ZIP_PATH.sha256"
UPLOAD_ZIP_PATH="$RELEASE_DIR/$APP_NAME-$VERSION-notary-upload.zip"

/bin/bash "$ROOT_DIR/script/build_and_run.sh" --bundle-only

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "missing app bundle: $APP_BUNDLE" >&2
  exit 1
fi

if [[ "$SIGN_IDENTITY" != "-" ]]; then
  codesign \
    --force \
    --deep \
    --options runtime \
    --timestamp \
    --sign "$SIGN_IDENTITY" \
    "$APP_BUNDLE"
fi

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

if [[ -n "$NOTARY_PROFILE" ]]; then
  if [[ "$SIGN_IDENTITY" == "-" ]]; then
    echo "MYPAD_SIGN_IDENTITY must be a Developer ID Application identity for notarization" >&2
    exit 1
  fi

  (
    cd "$ROOT_DIR/dist"
    /usr/bin/ditto -c -k --norsrc --keepParent "$APP_NAME.app" "$UPLOAD_ZIP_PATH"
  )

  xcrun notarytool submit "$UPLOAD_ZIP_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait
  xcrun stapler staple "$APP_BUNDLE"
  xcrun stapler validate "$APP_BUNDLE"
fi

(
  cd "$ROOT_DIR/dist"
  /usr/bin/ditto -c -k --norsrc --keepParent "$APP_NAME.app" "$ZIP_PATH"
)

shasum --algorithm 256 "$ZIP_PATH" | tee "$SHA_PATH"
