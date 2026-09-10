# Architecture

## Current Architecture Direction

Scap is a local file library for screenshots and screen recordings.

The active flow is:

1. Create or choose a local folder.
2. Optionally set it as the macOS screenshot destination.
3. Watch the folder for changes.
4. Recursively scan supported screenshot and recording files.
5. Build in-memory library items.
6. Store lightweight metadata locally.
7. Run OCR locally for supported screenshots when enabled.
8. Show thumbnails/list rows.
9. Search, annotate, combine, open, reveal and move files to Trash.

Direct capture code is legacy during the pivot and should not drive new work unless explicitly reactivated.

## Stack

- Swift
- SwiftUI
- AppKit where necessary
- Apple Vision for local OCR
- UserDefaults / AppStorage for prototype persistence
- FileManager
- DispatchSource file watching
- local thumbnails via AppKit
- SQLite + FTS5 later if the library outgrows prototype persistence

## Active Modules

```text
Scap/
  App/
    ScapApp.swift
    AppState.swift
    SettingsStore.swift
    KeyboardShortcut.swift
    HotKeyManager.swift
  Capture/
    Legacy direct-capture code, not the default product flow
  UI/
    MenuBar/
    Library/
    Settings/
```

Future extraction candidates:

```text
Scap/
  Services/
    FolderWatcher.swift
    ScreenshotFolderService.swift
    LibraryImportService.swift
    OCRService.swift
  Storage/
    LibraryDatabase.swift
    LibraryMetadataStore.swift
```

## Folder Flow

`Use for Screenshots` should:

1. create `~/Pictures/Scap`,
2. run macOS screenshot location setup,
3. restart the relevant system UI service when needed,
4. set the watched folder,
5. scan the folder,
6. show new files as they appear.

## Import Flow

Manual import should:

1. open a native file picker,
2. allow screenshots and recordings,
3. create library items for supported file types,
4. merge imported items without duplicates,
5. preserve original files.

## Delete Flow

Delete actions should move files to the macOS Trash.

Do not permanently delete files by default.

Batch deletion should:

1. collect selected items,
2. confirm the action,
3. move files to Trash,
4. remove successful items from the visible list,
5. rescan the watched folder.

## Search

Current search runs locally and can stay in memory for the prototype.

Search fields:

- filename/title
- note
- category
- project
- tags
- file type
- path
- OCR text

## Permissions

The normal flow should not require Screen Recording permission.

Folder access is user-granted through native open panels or normal user folders.

If future direct capture returns, it must be treated as a separate explicit scope.
