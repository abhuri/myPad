#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/.build/self-tests"
OUTPUT_BINARY="$OUTPUT_DIR/note-store-self-tests"

mkdir -p "$OUTPUT_DIR"

swiftc \
  -swift-version 5 \
  -parse-as-library \
  -target arm64-apple-macosx14.0 \
  "$ROOT_DIR/Sources/myPad/Models/EditorSettings.swift" \
  "$ROOT_DIR/Sources/myPad/Models/Note.swift" \
  "$ROOT_DIR/Sources/myPad/Models/SessionState.swift" \
  "$ROOT_DIR/Sources/myPad/Support/MarkdownPreviewParser.swift" \
  "$ROOT_DIR/Sources/myPad/Support/MarkdownTableFormatter.swift" \
  "$ROOT_DIR/Sources/myPad/Stores/NoteStore.swift" \
  "$ROOT_DIR/Tests/NoteStoreSelfTests/main.swift" \
  -o "$OUTPUT_BINARY"

"$OUTPUT_BINARY"
