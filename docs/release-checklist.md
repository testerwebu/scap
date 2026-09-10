# Release Checklist

Use this checklist before sharing Scap with reviewers.

## Repository

- `.gitignore` exists and excludes Xcode build/cache artifacts.
- No `DerivedData`, `.DS_Store`, `.xcuserdata`, `.app`, `.dSYM`, `.xcarchive` or `.xcresult` files are committed.
- README explains that the project is an early prototype.
- README explains that no open-source license is provided.
- Build instructions work from the repository root.

## Product

- Demo flow works with a local screenshots folder.
- `Use for Screenshots` creates/uses `~/Pictures/Scap`.
- Folder watching updates the library after new screenshots appear.
- Open, reveal and move-to-Trash actions work as expected.
- OCR runs locally and does not require an account.
- Annotation/board workflows avoid modifying originals unexpectedly.

## Privacy

- No backend endpoints are configured.
- No analytics SDK is present.
- No cloud sync is enabled.
- Screenshots, recordings, notes, tags and OCR text remain local.

## Build

- Release build succeeds:

```sh
xcodebuild build \
  -project apps/mac/Scap.xcodeproj \
  -scheme Scap \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/scap-derived
```

## Not Ready Yet

- Public release.
- Installer distribution.
- Notarized binary.
- Automated regression test coverage.
