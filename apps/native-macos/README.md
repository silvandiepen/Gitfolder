# GitFolder macOS App

Native macOS menu bar app for GitFolder.

## Development

```bash
cd apps/native-macos
xcodegen generate
open GitFolder.xcodeproj
```

The generated `.xcodeproj` is ignored. Source lives in `GitFolder/`.

## Phase 1

- Menu bar app only.
- Local config storage.
- Native folder picker.
- Security-scoped bookmarks for selected folders.
- System Git command runner.
- Safe sync engine before App Store polish.
