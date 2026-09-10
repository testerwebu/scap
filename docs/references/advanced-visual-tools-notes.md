# Advanced Visual Tools Notes

These notes guide post-V0.1 work for annotation, boards and scrolling screenshots.

## Priority

1. Basic Annotation and Redaction.
2. Combine Screenshots and Boards.
3. Scrolling Screenshots.

This order exists because annotation is most useful and easiest to validate, boards fit the Scap library model well, and scrolling screenshots carry the highest macOS permission and reliability risk.

## Product Principles

- Keep Scap a fast visual pocket, not a heavy editor.
- Keep files local.
- Preserve original screenshots by default.
- Prefer saved copies over destructive edits.
- Make advanced features optional.
- Do not make the normal library workflow depend on capture permissions.

## Shared UX Rules

- Use compact controls.
- Prefer icon buttons with tooltips.
- Avoid nested panels and large inspector surfaces in MVP.
- Keep primary actions visible: save, copy, export, cancel.
- Every generated result should be easy to find in the Scap library.

## Shared Output Rules

Generated files should:

- be local,
- use predictable names,
- be indexed by the existing library scanner,
- keep the original file untouched,
- support copy/export flows.

Recommended suffixes:

- annotated copy: `- Annotated YYYY-MM-DD HH.mm.ss.png`,
- board: `Board - YYYY-MM-DD HH.mm.ss.png`,
- scrolling capture: `Scrolling Capture - YYYY-MM-DD HH.mm.ss.png`.

## Shared Data Model Direction

Future item kinds may include:

- `screenshot`,
- `recording`,
- `board`.

Future derivative metadata may include:

- source item IDs,
- source file paths,
- derivative kind,
- created date,
- render settings,
- inherited tags,
- project assignment.

## Privacy

All advanced visual tools must remain local by default.

Do not upload:

- screenshots,
- recordings,
- annotations,
- OCR text,
- board source files,
- generated boards,
- scrolling captures.

## Risk Notes

Annotation risk is mainly UI precision and safe file output.

Board risk is mainly rendering consistency, memory use and selection UX.

Scrolling screenshot risk is mainly permissions, automation reliability, overlap detection and app compatibility.

## Manual QA Checklist

- Original files stay unchanged.
- Generated files appear in the library.
- Copy actions place valid images on the clipboard.
- Export writes valid PNG files.
- Failed actions do not leave broken library items.
- Large images do not freeze the app.
- Dark and light appearance both remain usable.
