# Phase 08 - Search Polish

## Goal

Make local search feel like the primary way to retrieve screenshots and recordings.

## Read First

- docs/04-data-model.md
- docs/07-copy.md

## Scope

Search:

- filename/title,
- kind: screenshot or recording,
- path,
- date,
- size where useful,
- note/category/project/tags,
- OCR text from Phase 07,
- ranked results, with stronger fields such as title/tags above path,
- match reason display.

UI:

- search field in library window,
- search field in menu bar popover,
- empty result state,
- visible count.
- clear search action,
- filters for all/screenshots/recordings/pinned/has OCR text,
- sorting by relevance/newest/oldest/name.

## Out of Scope

- Remote search.
- Direct capture.

## Acceptance

- Search filters visible library items.
- Search works across tiles, list and list with preview.
- Selection and batch delete still work on filtered results.
- Results are ranked by useful fields.
- The UI explains why an item matched the current query.
