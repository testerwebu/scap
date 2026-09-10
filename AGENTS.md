# AGENTS.md

You are working on Scap.

Scap is a tiny native macOS library for screenshots and screen recordings. Build the macOS app first. Do not start the landing page until the app V0.1 is real.

Before working, read only the files relevant to the current task.

Always read:

- docs/00-index.md
- docs/01-product.md
- docs/02-design.md
- docs/roadmap/00-roadmap.md

Then read the specific phase file from `docs/roadmap/`.

Do not read all roadmap phase files unless explicitly asked.

## Hard Rules

- Do not use Electron.
- Do not add backend.
- Do not add accounts.
- Do not add cloud sync.
- Do not start the landing page before Phase 13.
- Do not implement more than one phase at once.
- After every phase, the app must build and launch.
- Screenshots, recordings and metadata must stay local in V0.1.
- Do not reintroduce direct screen capture as the active V0.1 flow.
- Do not require Screen Recording permission for the normal V0.1 workflow.

## Current Scope

- The active product is file-library based, not direct-capture based.
- Scap can set a local Scap folder as the macOS screenshot destination.
- Users keep using normal macOS screenshot and screen recording shortcuts.
- Scap watches the chosen folder and indexes supported files.
- Supported V0.1 file types are common screenshot images and screen recordings: PNG, JPG/JPEG, HEIC, TIFF, GIF, MOV, MP4 and M4V.
- Supported V0.1 library actions are browse, search, open, reveal, select and move to Trash.
- Supported V0.1 view modes are tiles, list and list with preview thumbnails.
- Supported V0.1 organization fields are title, note, category, project, tags, source path, created/modified date and pinned/favorite state.
- Search covers filename/title, note, category, project, tags, source path, file type, date and local OCR text where available.
- Do not implement cloud sync in V0.1.
- Do not implement team sharing in V0.1.

## Tech Stack

- Swift
- SwiftUI
- AppKit where necessary
- local folder indexing and watching
- UserDefaults / AppStorage
- FileManager trash integration
- SQLite + FTS5 later
- local-first storage

Direct capture services under `Scap/Capture/` are legacy/pivot leftovers unless a later explicit phase reactivates them.

Post-V0.1 stack:

- Quick Look previews
- optional export flows

## Important Structure Note

- `apps/mac/Scap.xcodeproj` is the active native macOS project.
- Do not create a fake Xcode project file manually.

## Output After Work

- What changed
- Files touched
- How to test
- Risks / next steps
