# GitHub Review Notes

Scap can be shared as a private GitHub repository for product, design and technical review.

## Suggested Repository Description

Native macOS screenshot and screen-recording library. Local-first, private by default, built with SwiftUI and AppKit.

## Suggested README Positioning

Use this framing when sharing the repository:

> Scap is an early native macOS prototype for organizing screenshots and screen recordings locally. It is ready for private feedback, not public distribution.

## What Reviewers Should Look At

- Native macOS architecture under `apps/mac/Scap/`.
- Product direction in `docs/01-product.md`.
- Privacy model in `docs/05-privacy.md`.
- Roadmap in `docs/roadmap/00-roadmap.md`.
- Current app behavior via the `Scap` Xcode scheme.

## What Reviewers Should Ignore

- Lack of installer/notarization.
- Future web/landing page work in `apps/web/`.
- Legacy capture code unless reviewing whether it should be deleted or archived.

## Known Gaps

- No test target yet.
- No distribution packaging yet.
- No public license.
- App is not ready for general users.

## Last Verified Build

```sh
xcodebuild build \
  -project apps/mac/Scap.xcodeproj \
  -scheme Scap \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/scap-derived
```

Result:

```text
** BUILD SUCCEEDED **
```
