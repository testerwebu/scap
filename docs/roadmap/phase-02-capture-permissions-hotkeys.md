# Phase 02 - System Screenshot Folder and Hotkeys

This file keeps its historical filename for continuity. It no longer describes Screen Recording permission or direct capture.

## Goal

Let Scap become the default destination for macOS screenshots and provide a shortcut to open the app quickly.

## Read First

- docs/references/macos-screenshot-folder-notes.md
- docs/01-product.md
- docs/03-architecture.md

## Scope

- Add global/local shortcut support for opening Scap.
- Add `Use for Screenshots`.
- Create `~/Pictures/Scap` if needed.
- Set macOS screenshot destination to that folder after user action.
- Store watched folder path locally.
- Refresh or rescan after setup.
- Explain that users keep using normal macOS screenshot shortcuts.

## Out of Scope

- Capture Area.
- Capture Window.
- Capture Screen.
- Screen Recording permission detection.
- Direct capture APIs.
- Saving captured images produced by Scap.

## Acceptance

- User can click `Use for Screenshots`.
- New macOS screenshots save into the Scap folder.
- The app watches or indexes that folder.
- Shortcut opens Scap without starting a capture flow.
