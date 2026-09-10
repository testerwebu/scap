# Phase 15 - Scrolling Screenshots

Post-V0.1 and after Phase 14 unless explicitly requested earlier.

## Goal

Let users create one long screenshot from scrollable content while keeping the feature local and honest about technical limits.

This phase is the most technically risky of the three advanced features. It should be planned and tested separately from normal library import.

## Product Position

Scrolling Screenshot is an optional advanced capture feature. It should not replace the active Scap V0.1 model where users keep using macOS screenshot and recording shortcuts and Scap watches/imports files.

Do not make the normal app depend on Screen Recording permission again.

## Target Flow

1. User chooses `Scrolling Capture` from the main window or menu bar.
2. Scap asks the user to select an area or window.
3. Scap captures the visible region.
4. Scap scrolls down and captures additional frames.
5. Scap stitches frames into one vertical image.
6. Scap saves the result to the local library.
7. User can tag, describe, copy or export the result.

## MVP Scope

The MVP should focus on browsers and simple scrollable views.

Required:

- select capture area,
- capture first frame,
- scroll down,
- capture subsequent frames,
- stitch into one vertical image,
- save to Scap library,
- default name `Scrolling Capture - date and time`,
- cancel during capture.

## UX Requirements

- Show a small overlay: `Capturing scrolling screenshot...`
- Include `Cancel`.
- After success, show `Saved to Scap`.
- On failure, show: `Scrolling capture failed. Try selecting a smaller area or scrolling manually.`
- Do not save failed attempts as final screenshots.
- Do not promise compatibility with every app.

## Technical Risks

- macOS permissions may be required for real capture and scroll automation.
- Different apps scroll differently.
- Sticky headers and repeated UI can create duplicate regions.
- Overlap detection may fail on plain or repetitive content.
- Large captures can consume significant memory.
- Multi-display and Retina scaling can complicate coordinates.

## Permission Rules

This feature may require explicit permissions depending on the chosen implementation.

It must be isolated from the normal Scap library flow:

- normal folder watching should still work without Screen Recording permission,
- permission messaging must clearly say it is only for scrolling capture,
- users should be able to ignore this feature and keep using Scap normally.

## Stitching Strategy

MVP can start with simple vertical stitching:

1. Capture frames of the same rectangle.
2. Estimate overlap between consecutive frames.
3. Remove duplicated overlap.
4. Compose one tall PNG.

If overlap detection is unstable, provide a manual fallback later:

- user scrolls manually,
- Scap captures frames,
- user confirms or adjusts order,
- Scap stitches the result.

## File Output

Recommended name:

```text
Scrolling Capture - YYYY-MM-DD HH.mm.ss.png
```

The saved file should be indexed as a normal screenshot item.

## Premium / Later Ideas

- Better overlap detection.
- Automatic duplicate fragment removal.
- Export quality selection.
- PNG or PDF output.
- Browser-specific full-page capture.
- Manual scrolling capture mode.

## Out of Scope

- Web extension in MVP.
- Cloud upload.
- Video recording.
- OCR as part of this feature unless OCR already exists as a separate module.
- Guaranteed support for every app.
- Reworking the entire Scap app around direct capture.

## Acceptance Criteria

- User can start Scrolling Capture from the app.
- User can cancel during capture.
- Successful captures are saved as one local PNG.
- Result appears in Scap library.
- Failed captures show a clear error and do not create broken final files.
- Normal Scap folder/import workflow still works without capture permissions.

## Implementation Notes

- Treat this as an advanced, isolated capture module.
- Keep UI copy conservative.
- Build a small internal test set with browser pages, long documents and chat-like views.
- Do not start this phase until annotation and board workflows are stable.
