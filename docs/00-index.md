# Documentation Index

Scap is a native macOS screenshot and screen recording library.

Current direction:

- Scap works primarily with local files and folders.
- The app can set `~/Pictures/Scap` as the macOS screenshot destination.
- Users keep using normal macOS screenshot and recording shortcuts.
- The app watches a chosen folder, imports existing files, indexes them and helps users find, annotate, combine or delete them.
- OCR runs locally with Apple Vision.

## Core Docs

- `docs/01-product.md` - product definition and scope
- `docs/02-design.md` - UI and interaction guidelines
- `docs/03-architecture.md` - macOS app architecture
- `docs/04-data-model.md` - library item model and future database
- `docs/05-privacy.md` - local-first privacy rules
- `docs/06-pricing.md` - pricing assumptions
- `docs/07-copy.md` - product and UI copy
- `docs/github-review.md` - notes for sharing the repository privately
- `docs/release-checklist.md` - checklist before review or distribution

## Roadmap

- `docs/roadmap/00-roadmap.md` - build order and phase rules
- `docs/roadmap/phase-00-project-setup.md`
- `docs/roadmap/phase-01-menu-bar-library-shell.md`
- `docs/roadmap/phase-02-capture-permissions-hotkeys.md`
- `docs/roadmap/phase-03-area-capture.md`
- `docs/roadmap/phase-04-local-store.md`
- `docs/roadmap/phase-05-capture-types.md`
- `docs/roadmap/phase-06-organization.md`
- `docs/roadmap/phase-07-ocr-screenshots.md`
- `docs/roadmap/phase-08-search.md`
- `docs/roadmap/phase-09-settings.md`
- `docs/roadmap/phase-10-polish.md`
- `docs/roadmap/phase-11-packaging.md`
- `docs/roadmap/phase-12-annotation-redaction.md`
- `docs/roadmap/phase-13-landing.md`
- `docs/roadmap/phase-14-combine-screenshots-boards.md`
- `docs/roadmap/phase-15-scrolling-screenshots.md`

## References

- `docs/references/macos-screenshot-folder-notes.md` - active screenshot folder/import notes
- `docs/references/local-first-storage-notes.md` - local storage rules
- `docs/references/apple-design-notes.md` - platform UI notes
- `docs/references/macos-screen-capture-notes.md` - legacy direct-capture notes, not active guidance
- `docs/references/advanced-visual-tools-notes.md` - notes for annotation, boards and scrolling screenshots

## Phase Reading Rule

For any phase:

1. Read `AGENTS.md`.
2. Read this file.
3. Read `docs/01-product.md`, `docs/02-design.md` and `docs/roadmap/00-roadmap.md`.
4. Read only the current phase file and references listed there.

Do not use legacy direct-capture docs as implementation guidance unless the user explicitly reopens that scope.
