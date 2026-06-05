# macOS Permissions

## Status bar app

GitFolder should launch directly into the macOS status bar.

It should not show a main window by default.

## File access

The user must explicitly choose folders through a native macOS folder picker.

This gives the app access to those folders.

## Sandboxed app

If the app is sandboxed, it should store security-scoped bookmarks for selected folders.

Flow:

1. User chooses a folder.
2. App creates security-scoped bookmark data for that folder.
3. App stores the bookmark in app settings.
4. On app launch, app resolves the bookmark.
5. App calls `startAccessingSecurityScopedResource()` before syncing.
6. App calls `stopAccessingSecurityScopedResource()` after syncing.

## Login item

Phase 1 can run while the app is open.

A later version should support:

```txt
Launch GitFolder at login
```

This can be handled through a login item.

## Background behavior

Recommended Phase 1 architecture:

- Menu bar app stays running.
- In-memory timer checks folders every X minutes.
- Settings stored locally.
- Logs stored locally.

Avoid a separate daemon/helper in Phase 1 unless needed.

## Settings storage

Suggested local storage:

```txt
~/Library/Application Support/GitFolder/config.json
~/Library/Application Support/GitFolder/logs/
```

## Notifications

Phase 1 can avoid notifications unless there is an error.

Suggested notifications:

- Sync failed.
- GitHub access failed.
- Folder permission lost.
- Conflict detected.

Do not notify on every successful sync.
