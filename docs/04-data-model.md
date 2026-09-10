# Data Model

## V0.1 Model Direction

Scap stores and indexes local files that already exist on disk.

The core object is a library item, not an internally captured image.

## Library Item

Fields:

- `id`: stable file URL or later database UUID
- `url`: local file URL
- `name`: filename without extension or user title later
- `kind`: screenshot or recording
- `fileExtension`
- `modifiedAt`
- `createdAt` when available
- `sizeInBytes`
- `thumbnail`
- `sourcePath`

Future metadata:

- title
- note
- category
- project
- tags
- pinned/favorite
- OCR text

## Supported File Kinds

Screenshots:

- PNG
- JPG/JPEG
- HEIC
- TIFF
- GIF

Recordings:

- MOV
- MP4
- M4V

## Storage Rules

V0.1 may begin with in-memory indexing plus UserDefaults for the watched folder path.

Later persistence should use:

- local SQLite database,
- local file metadata,
- FTS5 for search,
- stable references to original files.

Do not upload screenshots, recordings, notes, tags or OCR text.

## Delete Rules

Deletion from Scap should move files to Trash by default.

Batch deletion should store outcome counts:

- moved to Trash
- failed

Permanent deletion is not V0.1 behavior.

## Migration Note

Older docs may mention `CaptureType`. For the current V0.1 flow, use `PocketItemKind` or equivalent: screenshot or recording.
