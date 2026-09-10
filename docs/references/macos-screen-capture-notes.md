# macOS Screen Capture Notes

This document is legacy reference material.

It describes direct screen-capture considerations that were explored early in the project. Direct capture is not the active V0.1 workflow.

## Current Rule

Do not use this file to guide normal V0.1 implementation.

The active V0.1 flow is documented in:

- `docs/references/macos-screenshot-folder-notes.md`
- `docs/roadmap/00-roadmap.md`
- `docs/01-product.md`

## If Direct Capture Returns Later

If a future explicit phase reopens direct capture, it must handle:

- clear user-triggered capture only,
- macOS Screen Recording permission,
- native permission explanation,
- no hidden/background capture,
- no upload of captured content.

Until then, Scap should avoid Screen Recording permission by using macOS screenshot folder handoff and local file indexing.
