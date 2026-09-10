# Phase 03 - Folder Import and Live Indexing

This file keeps its historical filename for continuity. It no longer describes area capture.

## Goal

Load screenshots and screen recordings from local folders/files and keep the library updated.

## Read First

- docs/references/macos-screenshot-folder-notes.md
- docs/references/local-first-storage-notes.md
- docs/03-architecture.md

## Scope

- Choose watched folder.
- Import existing files manually.
- Recursively scan supported files.
- Detect screenshots and recordings by extension.
- Generate local thumbnails/icons.
- Watch the chosen folder for changes.
- Refresh library manually.
- Open and reveal files.
- Move individual files to Trash.

## Supported File Types

- PNG
- JPG/JPEG
- HEIC
- TIFF
- GIF
- MOV
- MP4
- M4V

## Out of Scope

- Direct screen capture.
- Screen Recording permission.
- OCR.
- Database persistence.
- Tags/projects/notes.

## Acceptance

- User can choose a folder and see supported files.
- User can import files manually.
- New files in the watched folder appear after watcher event or refresh.
- User can open, reveal and move files to Trash.
