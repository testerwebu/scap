# Phase 05 - File Types and Library Views

This file keeps its historical filename for continuity. It no longer describes capture types.

## Goal

Make the library easier to scan, filter and clean up across screenshots and recordings.

## Read First

- docs/02-design.md
- docs/04-data-model.md

## Scope

- Support screenshot and recording kinds.
- Add view modes:
  - tiles
  - list
  - list with preview thumbnails
- Use icon-only segmented view switcher with accessibility/help labels.
- Add selection mode.
- Add select visible.
- Add batch move to Trash.
- Keep sticky batch action bar visible while scrolling.

## Out of Scope

- Direct capture modes.
- Screen Recording permission.
- OCR.
- Annotation.

## Acceptance

- User can switch between all view modes.
- User can select many files far down the scroll view.
- User can delete selected files without returning to the top.
- Files are moved to Trash, not permanently deleted.
