# Phase 07 - OCR for Screenshots

Started early after the library-first pivot, because OCR is the core value that makes screenshots searchable by what they contain.

## Goal

Make local screenshot files searchable by recognized text.

## Scope

- Use local Apple Vision OCR.
- Queue OCR for screenshot image files in the library.
- Store OCR text locally.
- Include OCR text in search.
- Re-run OCR when file changes.
- Show detected text in the item detail panel.
- Allow manual OCR re-scan for a selected screenshot.

## Out of Scope

- Remote OCR.
- Uploading screenshots.
- OCR for videos unless explicitly scoped later.
- Direct capture.

## Acceptance

- A local screenshot file gets OCR text.
- Search can find the file by text inside the image.
- The user can inspect detected text from the detail panel.
- The user can manually re-scan OCR for a screenshot.
- No screenshot content leaves the Mac.
