# Changelog

## 2.0.1 - 2026-06-22

- Added Markdown edit, split, and preview modes with native preview rendering.
- Added Markdown table helpers for inserting, formatting, and converting selected delimited text.
- Added file opening from the File menu, Finder/app open events, and drag-and-drop.
- Added find and replace, tab renaming, session import/export, and split-view scroll sync.
- Improved Markdown preview rendering for tables, images, task lists, and nested list markers.
- Added Developer ID signing and notarization support to the release packaging script.

## 1.2.0 - 2026-06-17

- Added a status-bar toggle for showing and hiding line numbers.
- Replaced the line-number divider with an adaptive shaded gutter that works in light and dark themes.
- Removed the ruler separator that could extend above the editor text area.

## 1.1.3 - 2026-06-17

- Restored the stable in-app tab bar while disabling duplicate native macOS window tabbing.
- Removed the native-window registry that caused scattered windows and hidden notes.
- Added Swift self-tests for tab creation, tab closing, session restore, and duplicate note-id cleanup.
- Updated install cleanup so Spotlight does not show the staging `dist/myPad.app` as a second app.

## 1.1.2 - 2026-06-17

- Removed the experimental cross-platform prototype and related install documentation.

## 1.1.1 - 2026-06-17

- Added persisted editor line-number visibility controls.
- Disabled duplicate native macOS window tabbing so only myPad tabs are shown.

## 1.0.0 - 2026-06-17

- Added light and dark themes.
- Moved font, font size, word wrap, and zoom controls into the macOS menu bar.
- Added editor toolbar actions for bold, italic, bullets, numbered lists, and checkboxes.
- Added smart list continuation, indentation, numbered sublevels, and promote/exit behavior.
- Added Option-scroll zoom support.
- Added Save and Save As for `.txt` and `.md` files.
- Added saved-file path restore for tabs.
- Changed closing the final tab to quit the app.

## 0.1.0 - 2026-06-17

- Initial native macOS app scaffold.
- Added tabbed plain-text note editing.
- Added automatic session restore.
- Added editor font family, font size, word wrap, and zoom controls.
- Added macOS app bundle build script.
- Added install script for `/Applications` or `~/Applications`.
- Added generated blue notes app icon.
