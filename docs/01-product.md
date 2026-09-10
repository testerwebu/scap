# Product

## One-Liner

Scap is a small native Mac app that keeps screenshots and screen recordings in one local, searchable pocket.

## Current Product Direction

Scap is a local-first screenshot and screen-recording library. It is not positioned as a cloud workspace or a background surveillance-style recorder.

The default flow works with the way macOS already creates screenshots:

1. The user clicks `Use for Screenshots`.
2. Scap creates `~/Pictures/Scap`.
3. Scap tells macOS to save new screenshots and recordings there.
4. The user keeps using normal macOS shortcuts.
5. Scap watches the folder and updates the library automatically.

The app can also import existing screenshots and recordings from any local folder.

## Problem

People make screenshots quickly, then lose them on the Desktop, in Downloads or among random filenames.

They need a place to:

- collect screenshots and screen recordings,
- scan them visually,
- add lightweight context,
- search visible text locally,
- annotate or redact screenshots without changing originals unexpectedly,
- combine related screenshots into simple boards,
- delete useless files quickly,
- trust that everything stays local.

## Target Users

- freelancers
- designers
- developers
- marketers
- creators
- students
- people who work with clients and often need visual receipts, references or bug evidence

## Current Prototype Jobs

Scap should let users:

- set a Scap folder as the macOS screenshot destination,
- watch a chosen local folder,
- import existing screenshots and recordings,
- browse files as tiles, list or list with preview thumbnails,
- search by filename, type, path, title, note, project, category, tags and local OCR text,
- keep local metadata per item,
- pin useful items,
- annotate/redact screenshot copies,
- create simple screenshot boards,
- open a file,
- reveal a file in Finder,
- select many files,
- move selected files to Trash,
- keep all content on the Mac.

## Current Non-Goals

- cloud sync
- accounts
- team workspaces
- remote OCR
- analytics
- public web app
- packaged public distribution before signing/notarization is solved

## File Types

Supported library types:

- screenshots: PNG, JPG/JPEG, HEIC, TIFF, GIF
- recordings: MOV, MP4, M4V

## Success Criteria

The user can answer:

> Where is that screenshot I made a few days ago?

without searching the Desktop manually.

The app succeeds when it feels faster and calmer than Finder for screenshot cleanup and retrieval.
