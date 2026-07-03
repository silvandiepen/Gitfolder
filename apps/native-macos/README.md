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
- GitHub HTTPS token auth by default, with token storage in macOS Keychain.
- Advanced SSH support with optional security-scoped SSH key bookmarks.
- System Git command runner.
- Sandboxed Mac App Store build settings.

## App Store Archive

```bash
npm run macos:archive:app-store
```

The script generates the Xcode project, archives the Release build, and exports with `AppStoreExportOptions.plist`.
