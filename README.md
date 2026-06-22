# myPad

myPad is a small native macOS scratchpad app for quick notes.

The current release focuses on the basics: instant writing, in-app note tabs,
automatic session restore, theme switching, formatting helpers, font settings,
word wrap, line numbers, Markdown preview, table helpers, and zoom.

![myPad icon](Resources/AppIconSource.png)

## Features

- Fast native macOS app built with SwiftUI and AppKit.
- Single native macOS window with in-app note tabs.
- Automatic session restore after quitting and reopening the app.
- Open, drag in, Save, or Save As `.txt`, `.md`, and `.markdown` notes.
- Light and dark theme toggle.
- Edit, split, and preview modes for Markdown notes.
- Native Markdown preview for headings, paragraphs, blockquotes, lists, task
  lists, code blocks, horizontal rules, tables, links, inline formatting, and
  image blocks.
- Plain-text Markdown helpers for bold and italic.
- Smart plain-text lists with bullets, hierarchical numbered lists, clickable `[ ]` / `[x]` checkboxes, auto-continuation, Tab indentation, and empty-line promote/exit behavior.
- Markdown table helpers for inserting tables, formatting the current table, and
  converting selected CSV, TSV, or pipe-delimited text into a table.
- Scroll sync between the source editor and Markdown preview in split mode.
- Find and replace with find next, replace next, and replace all.
- Rename tabs without changing note contents.
- Export the current session to JSON or import another myPad session into new
  tabs.
- Font family, font size, word wrap, line number, and zoom controls in the menu bar.
- Zoom in, zoom out, and reset zoom with keyboard shortcuts and Option-scroll.
- Word count and estimated read time in the status bar.
- Lightweight local-only storage.
- Closing the final window quits the app.
- Blue macOS app icon.

## Requirements

- macOS 14 or later.
- Swift Package Manager.
- Xcode Command Line Tools or Xcode.

## Build And Run

From the project folder:

```bash
/bin/bash ./script/build_and_run.sh
```

The script builds the Swift package, creates a local app bundle at
`dist/myPad.app`, ad-hoc signs it, and opens the app.

## Install To Applications

From the project folder:

```bash
/bin/bash ./script/install_app.sh
```

The installer builds the app and copies it to `/Applications/myPad.app` when the
folder is writable. If `/Applications` is not writable, it falls back to
`~/Applications/myPad.app`.

After installation, search for `myPad` in Spotlight.

## Install With Homebrew

Install with:

```bash
brew tap abhuri/tap
brew install --cask mypad
```

To upgrade later:

```bash
brew update
brew upgrade --cask mypad
```

## Local Data

Scratch notes and saved-file paths are stored locally in the user's Application
Support folder:

```text
~/Library/Application Support/myPad/session.json
```

The app does not sync data, send telemetry, or use a server.

## Development Notes

The app is intentionally simple:

- `Sources/myPad/App` contains app startup and macOS lifecycle glue.
- `Sources/myPad/Stores` contains note/session persistence.
- `Sources/myPad/Views` contains SwiftUI views and the AppKit text editor bridge.
- `Resources` contains the generated app icon source and `.icns` file.
- `script` contains build and install helpers.

Build outputs such as `.build`, `build`, and `dist` are ignored by git.

## Roadmap Ideas

- Optional CI automation for Developer ID signing and notarized release uploads.
- More complete GitHub Flavored Markdown edge cases such as nested task lists and
  syntax highlighting.
- More advanced table navigation with Tab and Return inside cells.

## License

MIT License.
