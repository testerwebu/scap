# Phase 04 - Local Library Store

## Goal

Persist the local library enough that Scap feels stable between launches.

## Read First

- docs/04-data-model.md
- docs/references/local-first-storage-notes.md
- docs/03-architecture.md

## Scope

- Persist watched folder path.
- Restore watched folder on launch.
- Rebuild library index on launch.
- Prepare database schema for future metadata.
- Keep file references local.
- Keep delete behavior Trash-based.

## Later in This Area

- SQLite library database.
- FTS5 metadata search.
- Durable title/note/tag/project metadata.
- Missing-file handling.

## Out of Scope

- Cloud sync.
- Accounts.
- Direct capture.
- OCR.

## Acceptance

- App remembers watched folder.
- Library repopulates after relaunch.
- User can keep using the Scap folder as the screenshot destination.
