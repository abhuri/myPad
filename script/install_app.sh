#!/bin/bash
set -euo pipefail

APP_NAME="myPad"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
DEST_ROOT="/Applications"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

kill_processes_matching() {
  local pattern="$1"
  local pid
  local args

  while read -r pid args; do
    [[ -z "$pid" || "$pid" == "$$" || "$pid" == "$PPID" ]] && continue
    [[ "$args" != "$pattern" ]] && continue
    kill "$pid" >/dev/null 2>&1 || true
  done < <(ps -ax -o pid= -o args=)
}

if [[ ! -w "$DEST_ROOT" ]]; then
  DEST_ROOT="$HOME/Applications"
  mkdir -p "$DEST_ROOT"
fi

kill_processes_matching "$ROOT_DIR/dist/$APP_NAME.app/Contents/MacOS/$APP_NAME"
kill_processes_matching "$DEST_ROOT/$APP_NAME.app/Contents/MacOS/$APP_NAME"
sleep 0.2

MYPAD_SKIP_KILL=1 /bin/bash "$ROOT_DIR/script/build_and_run.sh" --bundle-only

DEST_APP="$DEST_ROOT/$APP_NAME.app"
rm -rf "$DEST_APP"
/usr/bin/ditto "$APP_BUNDLE" "$DEST_APP"
xattr -cr "$DEST_APP" >/dev/null 2>&1 || true
codesign --force --deep --sign - "$DEST_APP" >/dev/null

if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -u "$APP_BUNDLE" >/dev/null 2>&1 || true
  "$LSREGISTER" -f "$DEST_APP" >/dev/null 2>&1 || true
fi

/usr/bin/mdimport "$DEST_APP" >/dev/null 2>&1 || true
rm -rf "$APP_BUNDLE"

echo "$DEST_APP"
