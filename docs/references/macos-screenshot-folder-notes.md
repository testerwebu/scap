# macOS Screenshot Folder Notes

This is the active V0.1 reference for how Scap works with macOS screenshots.

## Principle

Scap should not fight the system screenshot permission model.

The app should let macOS keep making screenshots and recordings, then organize the files locally.

## Default Folder

Preferred default:

```text
~/Pictures/Scap
```

## System Handoff

When the user chooses `Use for Screenshots`, Scap may:

1. create the Scap folder,
2. set the macOS screenshot destination to that folder,
3. refresh system UI services as needed,
4. watch the folder,
5. index new screenshots and recordings.

Implementation may use:

```sh
defaults write com.apple.screencapture location "<folder>"
killall SystemUIServer
```

Run this only after a clear user action.

## Folder Watching

The app should detect new files through a local folder watcher and/or rescans.

Supported files:

- PNG
- JPG/JPEG
- HEIC
- TIFF
- GIF
- MOV
- MP4
- M4V

## User Control

Users should be able to:

- choose a watched folder,
- import files manually,
- refresh the library,
- reveal files in Finder,
- move files to Trash.

## Permissions

The normal V0.1 workflow should not request Screen Recording permission.
