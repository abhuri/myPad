# Contributing

Thanks for helping improve myPad.

## Local Setup

Build and run the app with:

```bash
/bin/bash ./script/build_and_run.sh
```

Install a local app bundle with:

```bash
/bin/bash ./script/install_app.sh
```

## Development Guidelines

- Keep the app lightweight and native.
- Prefer SwiftUI for layout and AppKit only where macOS text editing needs it.
- Keep scratch notes local-first.
- Avoid adding heavy dependencies unless they clearly improve the core app.
- Prioritize fast launch, tabs, session restore, font controls, word wrap, and
  zoom before secondary features.

## Pull Requests

- Keep changes focused.
- Explain the user-facing behavior change.
- Include manual verification steps when tests are not available.
