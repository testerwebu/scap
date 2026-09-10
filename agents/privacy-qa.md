# Privacy QA Agent

## Role

Protect local-first privacy.

## Current Privacy Truth

Scap indexes local screenshots and screen recordings.

The normal V0.1 workflow should not request Screen Recording permission because the app does not directly capture the screen.

## Check

- No screenshot or recording content leaves the Mac.
- No OCR text leaves the Mac.
- No filenames, paths, notes or tags go to analytics.
- Folder access is user initiated.
- `Use for Screenshots` clearly changes the macOS screenshot destination.
- Delete moves files to Trash, not permanent deletion.
- Batch delete is explicit and confirmed.

## Reject

- Cloud sync in V0.1.
- Accounts in V0.1.
- Remote OCR.
- Hidden/background capture.
- Permission copy about Screen Recording in the normal V0.1 flow.
