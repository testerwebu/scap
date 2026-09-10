# Phase 09 - Settings and Preferences

## Goal

Turn Settings into the control center for the library-first Scap workflow.

Scap no longer needs to capture the screen directly. The settings surface should help the user decide where macOS saves screenshots and recordings, how the app watches those files, and how much local text recognition should run automatically.

## Implemented Scope

- Show and manage the Scap screenshot destination.
- Set `~/Pictures/Scap` as the macOS screenshot and recording folder.
- Reset the macOS screenshot and recording folder back to Desktop.
- Choose, refresh and reveal the watched folder.
- Show library stats:
  - indexed item count
  - screenshot count
  - recording count
  - pinned count
  - detected-text count
  - total library size
- Add local OCR preferences:
  - automatic text recognition on/off
  - scan existing watched-folder files on/off
  - language selection for English, Polish, German, French, Spanish, Italian, Portuguese, Dutch, Czech, Ukrainian, Russian, Japanese, Korean, Chinese Simplified and Chinese Traditional
  - select all languages action
  - manual re-scan of all screenshots
- Keep OCR fully local through Apple Vision.
- Preserve appearance and shortcut preferences.

## Product Decision

Settings now reflects the import-based product direction:

- Scap organizes screenshots and recordings that already exist on the Mac.
- New macOS screenshots can flow into Scap by changing the system screenshot save folder.
- Screen Recording permission is not part of the core product path.
- Direct capture remains legacy code only and should not drive new UI decisions.

## Verification

- Build the macOS app with Xcode.
- Open Settings and confirm all sections render.
- Use `Use for Screenshots`, then make a macOS screenshot and confirm it appears in Scap.
- Use `Reset to Desktop` and confirm new screenshots return to Desktop.
- Toggle OCR off, add a new screenshot and confirm it does not auto-scan.
- Use `Re-scan All Screenshots` and confirm text recognition can still be run manually.
