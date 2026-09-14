# Scap

Scap is a native macOS app for keeping screenshots and screen recordings in one local, searchable library.

It is built for people who make screenshots constantly, then need a faster way to find, organize, annotate, combine or clean them up without sending private visual material to a cloud service.

## See It in Action

Browse screenshots, search text inside images, organize your library and annotate a copy.

![Scap step-by-step demo](docs/media/demo.gif)

[View the screenshots and walkthrough](docs/demo.md). Real native UI with fictional sample data; the GIF is a sequence of captured screenshots. This is an early prototype, not a production-release announcement.

## Status

Scap is an early macOS prototype. It builds locally and is suitable to share privately for product, design and technical review.

It is not yet packaged, notarized or ready for public distribution.

## What It Does

- Watches a local screenshot folder.
- Can set `~/Pictures/Scap` as the macOS screenshot destination.
- Imports existing screenshots and screen recordings from local folders.
- Supports common image and video formats: PNG, JPG/JPEG, HEIC, TIFF, GIF, MOV, MP4 and M4V.
- Shows captures as tiles, a compact list or a preview list.
- Searches by filename, file type, path, title, note, project, category, tags and local OCR text.
- Lets users pin items, add notes/tags/projects and filter their library.
- Runs OCR locally with Apple Vision.
- Supports local annotation/redaction workflows for screenshots.
- Creates simple boards from multiple screenshots.
- Opens files, reveals them in Finder and moves unwanted files to Trash.

## Privacy Model

Scap is local-first:

- no account,
- no backend,
- no cloud sync,
- no analytics in the current prototype,
- screenshots, recordings, notes, tags and OCR text stay on the Mac.

## Repository Notice

This repository is shared for private review and demonstration only. No open-source license is provided.

## Project Structure

```text
apps/mac/        Native macOS app
apps/web/        Placeholder for future marketing site work
docs/            Product, design, architecture and roadmap notes
agents/          Role prompts used while shaping the product
```

## Requirements

- macOS
- Xcode 16 or newer
- macOS 13+ deployment target

The current local build was verified with Xcode using the `Scap` scheme.

## Build

From the repository root:

```sh
xcodebuild build \
  -project apps/mac/Scap.xcodeproj \
  -scheme Scap \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/scap-derived
```

Expected result:

```text
** BUILD SUCCEEDED **
```

## Run

Open `apps/mac/Scap.xcodeproj` in Xcode and run the `Scap` scheme.

On first launch:

1. Choose an existing folder with screenshots or recordings, or click `Use for Screenshots`.
2. If using `Use for Screenshots`, Scap creates `~/Pictures/Scap` and points macOS screenshots there.
3. Keep using normal macOS screenshot shortcuts.
4. New supported files should appear in Scap automatically.

## Demo Flow

For a short review demo:

1. Launch Scap from Xcode.
2. Use `Use for Screenshots` or choose a local folder containing screenshots.
3. Create or import a few screenshots.
4. Switch between preview list, compact list and tiles.
5. Search by filename or visible text after OCR runs.
6. Add a note, project or tag in the detail panel.
7. Pin an item.
8. Open/reveal an item in Finder.
9. Try annotation or board creation with copied files only.

## Current Limitations

- No installer, signing identity for distribution or notarization yet.
- No automated test target yet.
- Metadata is prototype-level local persistence.
- Some legacy direct-capture code still exists in `apps/mac/Scap/Capture/`, but the active app flow is folder/import based.
- `apps/web/` is not a finished public landing page.

## Before Public Release

- Add automated tests for indexing, metadata, OCR triggering and destructive actions.
- Add packaging, signing and notarization.
- Decide final distribution channel.
- Replace prototype persistence with a more durable store if needed.
- Finish public-facing product copy and assets.
