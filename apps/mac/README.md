# Scap macOS App

Native macOS app for Scap.

## Stack

- Swift
- SwiftUI
- AppKit where needed
- Apple Vision for local OCR
- UserDefaults for prototype settings and metadata
- Local folder indexing and watching
- FileManager trash integration

## Current App

Scap is a library-first Mac app. It works with screenshots and recordings that already exist on the Mac instead of requiring a direct screen-capture engine.

Created so far:

- Xcode project and `Scap` scheme
- menu bar extra and popover
- global shortcut for showing the library
- watched folder picker
- Scap screenshot folder setup
- macOS screenshot save-location handoff
- manual screenshot/recording import
- recursive folder scan
- live folder watcher
- screenshot and recording detection
- tile, compact list and preview-list views
- local metadata for title, note, project, category, tags and pinned state
- local Apple Vision OCR for screenshots
- search and filters across files, metadata and OCR text
- settings panel for folder source, OCR, appearance and shortcut preferences
- open, reveal in Finder and move-to-Trash actions
- bulk selection and bulk delete
- annotation/redaction editor
- screenshot board editor

Known gaps:

- no test target yet
- no installer/signing/notarization for distribution yet
- no database-backed metadata store yet
- legacy direct-capture code remains under `Scap/Capture/`

## Build

From the repository root:

```sh
xcodebuild build \
  -project apps/mac/Scap.xcodeproj \
  -scheme Scap \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/scap-derived
```

## Run

Open `apps/mac/Scap.xcodeproj` in Xcode and run the `Scap` scheme.

## Hard Rules

- no Electron
- no backend
- no account
- no cloud sync
- no remote OCR
- no analytics in the current prototype
