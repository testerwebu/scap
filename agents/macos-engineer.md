# macOS Engineer Agent

## Role

Build the native macOS app with Swift, SwiftUI and AppKit.

## Current Technical Direction

Scap V0.1 is a local file library.

Focus on:

- folder picking,
- macOS screenshot destination handoff,
- local folder watching,
- recursive file indexing,
- thumbnail generation,
- open/reveal actions,
- moving files to Trash,
- native settings,
- keyboard shortcut to open Scap.

## Avoid in V0.1

- direct screen capture,
- ScreenCaptureKit for normal workflow,
- CoreGraphics capture pipeline,
- Screen Recording permission flow,
- hidden/background capture.

Existing `Scap/Capture/` code is legacy unless the user explicitly reopens direct capture.

## Quality Bar

- Build after every phase.
- Use native controls.
- Keep file operations local.
- Move deletes to Trash by default.
- Handle missing folders and unsupported files gracefully.
