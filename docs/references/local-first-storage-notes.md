# Local-First Storage Notes

Scap stores screenshot and recording references locally.

## Active V0.1 Storage

The app may start with:

- watched folder path in UserDefaults,
- in-memory indexing,
- file URLs,
- thumbnails generated locally.

Later phases can add:

- SQLite,
- FTS5,
- local metadata,
- OCR text,
- tags/projects/notes.

## File Handling

Do not scatter Scap-managed screenshots across random folders.

Preferred default:

```text
~/Pictures/Scap
```

The user may also choose another watched folder.

## Delete Handling

When a user deletes an item:

- move the file to Trash,
- remove it from the visible library,
- rescan the watched folder,
- report partial failures for batch delete.

Do not permanently delete files by default.

## Privacy

Treat screenshots and recordings as sensitive.

No screenshot content, recordings, notes, tags, OCR text or file paths should leave the device in V0.1.
