# Phase 12 - Basic Annotation and Redaction

Post-V0.1 unless explicitly requested earlier.

## Goal

Let users quickly mark up or hide parts of saved screenshots without turning Scap into a full graphics editor.

This phase is about fast, local, lightweight annotation for screenshots already stored in the Scap library.

## User Flow

1. User opens a screenshot from the library.
2. User clicks `Annotate`.
3. Scap opens a simple annotation editor.
4. User adds marks, text, numbered steps or blur.
5. User can cancel, save a copy, copy the result or export a PNG.
6. Original screenshot stays untouched unless a later explicit destructive flow is added.

## Default Toolbar

Use a compact toolbar:

```text
Arrow | Rectangle | Highlight | Text | Number | Blur | Undo | Save | Copy | Export
```

The toolbar should prioritize icons with tooltips. Avoid a heavy inspector panel in the first implementation.

## Tools

### Arrow

- Draw a straight arrow.
- Show draggable start and end handles when selected.
- Keep one simple stroke style in MVP.

### Rectangle

- Draw a transparent rectangle with a visible outline.
- Let the user resize it through corner handles.
- Use it for calling out UI areas, errors and important details.

### Highlight

- Draw a semi-transparent marker rectangle or freeform highlight.
- MVP can start with rectangular highlight only.
- Use a readable default color that works on light and dark screenshots.

### Text

- Add short editable text.
- Text should become editable when selected or double-clicked.
- Do not build font families, full typography controls or rich text in MVP.

### Numbered Steps

- Add small numbered circles: 1, 2, 3 and so on.
- Number should auto-increment per edited image.
- User can select and delete any step marker.

### Blur / Pixelate

- Hide sensitive areas such as emails, customer data, amounts, logins or IDs.
- MVP should choose one default mode first: blur or pixelate.
- Treat this as a visual redaction on the exported copy, not as a guarantee that original data is destroyed from the original file.

## Required Actions

- `Cancel`: close editor without saving.
- `Save as Copy`: render annotations into a new image file and add it to the library.
- `Copy Annotated Image`: render and copy final image to the pasteboard.
- `Export`: render and save as PNG through a native save panel.
- `Undo`: Cmd+Z reverts the last annotation action.
- `Redo`: Cmd+Shift+Z restores the reverted action.
- `Delete`: selected annotation can be removed.

## Data Model Notes

MVP can store annotations only in editor memory until the user saves a rendered copy.

Later non-destructive persistence may add:

- annotation document ID,
- source item ID,
- tool type,
- frame/points,
- color/style,
- text content,
- z-index,
- created/updated date.

Do not require this persistent annotation model for the first implementation if it slows the phase down.

## File Output

`Save as Copy` should create a new local PNG file near the source file or in the active Scap library folder.

Recommended naming:

```text
Original Name - Annotated YYYY-MM-DD HH.mm.ss.png
```

The saved copy should be indexed as a normal screenshot item.

## UX Requirements

- Editor opens quickly.
- Original file is safe by default.
- No floating palettes in MVP.
- Selection handles must be visible but subtle.
- Dragging annotations should feel immediate.
- Tool mode should be clear.
- Empty states and failures should use simple language.

## Out of Scope

- Editing screen recordings.
- Full Photoshop/Figma-like editor.
- Layers panel.
- Masks.
- Advanced typography.
- Cloud sharing.
- Team review.
- Destructive edits by default.
- Direct screen capture.

## Acceptance Criteria

- User can open a saved screenshot and enter annotation mode.
- User can add arrow, rectangle, highlight, text, numbered step and blur/pixelate.
- User can select and delete an annotation.
- Cmd+Z and Cmd+Shift+Z work inside the editor.
- `Cancel` closes without writing a file.
- `Save as Copy` creates a new image and the library shows it.
- `Copy Annotated Image` places the rendered image on the clipboard.
- `Export` writes a PNG through a save panel.
- Original screenshot remains available and unchanged.

## Implementation Notes

- Prefer SwiftUI for chrome and AppKit where image drawing or precise mouse handling is easier.
- Keep the render pipeline separate from the editor UI.
- Add tests or manual QA around original-file safety, output naming and copy/export behavior.
- This phase should not reintroduce Screen Recording permission.
