# Design

## Design Direction

Scap is a quiet native macOS utility for repeated use.

It should feel like a focused library and cleanup tool, not a marketing page and not a heavy file manager.

## Primary Screens

- menu bar popover
- library window
- settings window

## Library Window

The library window is the main workspace.

It should include:

- source/folder status,
- search,
- view mode switcher,
- visible item count,
- selection state,
- sticky batch action bar,
- tiles view,
- list view,
- list with preview thumbnails.

The sticky action bar should stay visible while scrolling, especially during multi-select cleanup.

## View Modes

Use icon-only segmented controls for view modes:

- tiles: `square.grid.2x2`
- list: `list.bullet`
- list plus preview: `rectangle.split.2x1`

Keep labels available through accessibility and hover help.

## Item UI

Each library item should expose:

- thumbnail or file icon,
- filename/title,
- type: screenshot or recording,
- date,
- size,
- path when useful,
- open,
- reveal in Finder,
- delete.

In selection mode:

- clicking a row/card toggles selection,
- selected items should have a clear accent outline or tinted background,
- batch delete should move items to Trash, not permanently delete them.

## Empty States

Empty states should steer users toward the current V0.1 workflow:

- choose a folder,
- use Scap as the macOS screenshot folder,
- import existing screenshots or recordings.

Do not say "Capture an area, window or screen" in V0.1 empty states.

## Tone

Short, practical and local-first.

Good:

- "Use for Screenshots"
- "Import Files"
- "Move to Trash"
- "No files imported yet."
- "New screenshots will appear here."

Avoid:

- permission-heavy copy,
- capture-mode promises,
- cloud/team language,
- dramatic productivity claims.

## Visual Rules

- Use native controls where possible.
- Keep cards at 8px radius or less.
- Prefer icons for compact tools.
- Do not nest cards inside cards.
- Do not use marketing hero layouts inside the app.
- Keep text compact enough for utility surfaces.
