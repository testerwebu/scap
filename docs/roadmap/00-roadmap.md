# Roadmap

## V0.1 Build Order

Do not start with the landing page.

Build order for the first usable local screenshot/recording library:

1. Phase 00 - Project setup
2. Phase 01 - Menu bar and library shell
3. Phase 02 - System screenshot folder and hotkeys
4. Phase 03 - Folder import and live indexing
5. Phase 04 - Local library store
6. Phase 05 - File types and library views
7. Phase 06 - Organization
8. Phase 08 - Basic search
9. Phase 09 - Settings
10. Phase 10 - Polish
11. Phase 11 - Packaging

Post-V0.1:

- Phase 07 - OCR for screenshots
- Phase 12 - Basic annotation and redaction
- Phase 13 - Landing page
- Phase 14 - Combine screenshots and boards
- Phase 15 - Scrolling screenshots

Do not start the landing page before the native macOS V0.1 works.

When working on a phase, read only that phase file and the documents referenced inside it.

## Current Product Direction

Scap no longer uses direct screen capture as the active V0.1 workflow.

The app should:

- create or use a local Scap folder,
- optionally set that folder as the macOS screenshot destination,
- let the user keep using normal macOS screenshot/recording shortcuts,
- watch the chosen folder,
- import existing screenshots and recordings,
- index supported files,
- show tiles, list and list with preview modes,
- support multi-select cleanup,
- move deleted files to Trash.

Direct capture, ScreenCaptureKit and Screen Recording permission are not part of the normal V0.1 flow. Existing capture code is legacy during the pivot and should not guide new work.

## Hard Rules

- Do not implement more than one phase at a time.
- If working on Phase 02, do not start Phase 03.
- If working on Phase 03, do not start Phase 04.
- The app must build and launch after every phase.
- Do not add backend, accounts, cloud sync, analytics, subscriptions or license keys in V0.1.
- Do not create fake `.xcodeproj` files manually.
- The real Xcode project must be created during Phase 00.
- V0.1 is file-library based.
- Do not reintroduce direct capture unless the user explicitly changes scope again.
- Do not implement OCR, annotations, redaction, cloud sync or team sharing in V0.1.
- Advanced visual tools must be implemented as isolated post-V0.1 phases.
- Basic annotation comes before boards.
- Boards come before scrolling screenshots.
- Scrolling screenshots must not make the normal folder/import workflow depend on Screen Recording permission.

## Current Expected Pre-Phase-00 Structure

Before Phase 00, it is okay for these folders to contain only `.gitkeep`:

- apps/mac/Scap/
- apps/web/app/
- apps/web/components/
- apps/web/public/

During Phase 00, Codex should create the real native macOS project in `apps/mac/`.

During Post-V0.1 Phase 13, Codex should create the real Next.js landing in `apps/web/`.
