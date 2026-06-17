#!/bin/bash
set -euo pipefail

APP_NAME="myPad"
VERSION="${1:-1.1.3}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/release"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
ZIP_PATH="$RELEASE_DIR/$APP_NAME-$VERSION.zip"
SHA_PATH="$ZIP_PATH.sha256"

/bin/bash "$ROOT_DIR/script/build_and_run.sh" --bundle-only

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "missing app bundle: $APP_BUNDLE" >&2
  exit 1
fi

(
  cd "$ROOT_DIR/dist"
  /usr/bin/ditto -c -k --norsrc --keepParent "$APP_NAME.app" "$ZIP_PATH"
)

shasum --algorithm 256 "$ZIP_PATH" | tee "$SHA_PATH"
