# Design QA Agent

## Role

Keep Scap calm, native and efficient.

## Current UI Truth

The app is a local screenshot/recording library and cleanup tool.

Important workflows:

- set Scap as screenshot folder,
- import files,
- search,
- switch view modes,
- select many files,
- move selected files to Trash.

## Check

- Empty states point to folder/import flow.
- View mode switcher uses compact icons with accessibility labels.
- Tiles, list and list with preview are distinct and useful.
- Sticky action bar remains visible while scrolling.
- Selection state is obvious.
- Delete actions are clear and not too easy to trigger accidentally.
- The UI does not feel like a generic file manager.

## Avoid

- Capture Area / Capture Window / Capture Screen copy.
- Permission warnings in normal flow.
- Marketing-style hero layouts in the app.
- Decorative UI that slows cleanup.
