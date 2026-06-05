# Phase 1 Scope

## Summary

Phase 1 is a minimal paid macOS menu bar app distributed through the Mac App Store.

It should prove that the core workflow works:

```txt
Folder → GitHub repository → interval → automatic snapshot commits
```

## Must have

- App lives in the macOS status bar.
- App keeps running in the background while open.
- User can add a local folder.
- User can connect that folder to a GitHub repository.
- User can choose a sync interval.
- App checks for changes every X minutes.
- App commits changes automatically.
- App pushes changes to GitHub.
- App shows last sync status.
- App shows basic errors.
- User can sync manually.
- User can pause syncing.

## GitHub access

Phase 1 should use existing local Git and GitHub SSH configuration.

The user supplies a repo URL like:

```txt
git@github.com:silvandiepen/my-folder.git
```

OAuth and repository picking are deferred.

## Folder access

The user selects folders through the native macOS folder picker.

For sandboxed builds, the app should save security-scoped bookmarks so it can access selected folders after restart.

## Default sync interval

Default: 15 minutes.

Allowed values:

- 5 minutes
- 15 minutes
- 30 minutes
- 60 minutes

## Initial folder setup

When adding a folder:

1. Select local folder.
2. Enter GitHub repository URL.
3. Choose branch, default `main`.
4. Choose sync interval.
5. Test GitHub access.
6. Initialize Git if needed.
7. Save configuration.
8. Run first sync.

## Out of scope

- GitHub OAuth.
- Creating repositories from the app.
- Listing GitHub repositories.
- Merge conflict resolution UI.
- File restore UI.
- Visual diff viewer.
- Team collaboration.
- Non-GitHub providers.
- iCloud/Dropbox integration.
- App Store polish.
