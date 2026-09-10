# Phase 11 - Packaging

## Goal

Prepare the native macOS app for distribution/testing.

## Scope

- App icon.
- Bundle metadata.
- Local signing/notarization notes later.
- First-run notes for setting screenshot folder.
- README instructions.
- Basic QA checklist.

## Must Document

- The app indexes local screenshot/recording files.
- `Use for Screenshots` changes the macOS screenshot destination.
- Files deleted from Scap are moved to Trash.
- No Screen Recording permission is required for the normal V0.1 flow.

## Out of Scope

- Landing page.
- StoreKit/licensing.
- Cloud sync.
- Direct capture permission flow.

## Acceptance

- User can run a packaged build.
- First-run behavior is understandable.
- Packaging docs match the current product direction.
