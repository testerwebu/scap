# Phase 14 - Combine Screenshots and Boards

Post-V0.1. Build after Phase 12 unless the user explicitly changes priority.

## Goal

Let users combine multiple screenshots into one clean visual board for bug reports, feedback, inspiration, comparisons and client communication.

This is not a full design tool. It is a fast board generator for selected Scap items.

## User Flow

1. User selects at least two screenshots in the library.
2. Scap shows `Create Board` in the selection toolbar and context menu.
3. User opens a board preview.
4. User chooses layout, background and simple styling.
5. User can reorder screenshots before saving.
6. User creates the board.
7. Scap saves the board as a new local library item.
8. User can copy or export the board as PNG.

## MVP Layouts

### Vertical Stack

- Screenshots are placed one below another.
- Best for instructions, page reviews and long comparisons.
- Use consistent spacing between images.

### Horizontal Row

- Screenshots are placed side by side.
- Best for before/after or two-state comparisons.
- Scale items to a consistent visual height.

### Grid

- Screenshots are placed in an automatic grid.
- Best for inspiration, campaign review and sets of examples.
- Start with automatic 2-column/3-column behavior based on item count and preview width.

## Later Layout

### Freeform Canvas

- User manually moves screenshots on a canvas.
- This is not part of MVP unless explicitly requested.
- Do not introduce freeform layers or Figma-like controls in the first board phase.

## Inputs

- Minimum: 2 screenshots.
- Recommended maximum in MVP: 12 screenshots.
- Supported input should start with image screenshots only.
- Screen recordings are out of scope for rendered boards unless represented by a generated still frame later.

## Board Options

MVP options:

- layout: vertical, horizontal, grid,
- background: transparent, light, dark,
- spacing: one sensible default, optional simple control later,
- rounded corners: on/off,
- shadows: on/off,
- title: default `Untitled Board`.

Do not add advanced typography, masks, filters or effects in MVP.

## Required Actions

- `Create Board`: render and save board as a new library item.
- `Copy Board`: copy rendered PNG to clipboard.
- `Export Board`: export rendered PNG through native save panel.
- Remove screenshot from board preview before saving.
- Reorder screenshots by drag and drop before saving.

## Library Behavior

Boards should be first-class library items, separate from screenshots.

Required metadata additions:

- item kind: `board`,
- source item IDs or source file paths,
- board layout,
- board title,
- created date,
- tags inherited or assigned.

Board files should remain local and should be indexed by the same library flow as screenshots.

## Suggested File Naming

```text
Board - YYYY-MM-DD HH.mm.ss.png
```

If user sets a board title, use a sanitized title:

```text
Client Feedback - YYYY-MM-DD HH.mm.ss.png
```

## Tag and Project Behavior

MVP should choose one clear behavior:

- inherit project if all selected screenshots belong to the same project,
- otherwise leave board unassigned,
- inherit unique tags from selected screenshots,
- allow user to edit tags later through the normal details panel.

## UX Requirements

- `Create Board` appears only when at least two eligible screenshots are selected.
- Preview should be fast and stable.
- Dragging to reorder should feel smooth and show insertion feedback.
- Empty or invalid selection should not open a broken preview.
- After creation, show `Board saved to Scap`.

## Out of Scope

- Full graphic editor.
- Freeform canvas in MVP.
- Layers panel.
- Masks and special effects.
- Editing original screenshots.
- Cloud sharing.
- Collaboration.

## Acceptance Criteria

- User can select 2-12 screenshots and open `Create Board`.
- User can choose vertical, horizontal or grid layout.
- User can choose transparent, light or dark background.
- User can toggle rounded corners and shadow.
- User can reorder and remove screenshots in preview.
- User can save a board as a new local Scap item.
- User can copy the board to clipboard.
- User can export the board as PNG.
- Board appears in library and can be searched/opened like other items.

## Implementation Notes

- Build the renderer as a separate service from the preview UI.
- Use AppKit/CoreGraphics rendering for predictable PNG output.
- Keep board generation local.
- Avoid adding a database migration until the existing metadata store needs it; if persistence is already structured, add `board` as a new kind.
