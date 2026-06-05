# GitFolder

GitFolder is a small macOS menu bar app that automatically versions selected folders with GitHub.

Choose a folder, connect it to a repository, set a sync interval, and GitFolder creates quiet snapshot commits whenever files change.

The goal is to make a normal folder feel versioned by default without requiring the user to manually use Git.

## Product idea

GitFolder runs in the macOS status bar. It keeps watching configured folders in the background and periodically checks whether anything changed. When a folder has changes, GitFolder creates a snapshot commit and pushes it to GitHub.

The app is not meant to replace Time Machine, iCloud Drive, Dropbox, or a full backup system. It is focused on automatic version history for selected folders.

## Phase 1

Phase 1 is a personal macOS utility with a small scope:

- Status bar app only.
- Connect to GitHub using existing local Git/SSH access.
- Request file access through macOS folder selection.
- Add one or more local folders.
- Connect each folder to a GitHub repository.
- Check for changes every configured number of minutes.
- Commit changed files automatically.
- Pull/rebase before pushing when safe.
- Push commits to GitHub.
- Show sync status and basic errors.
- Allow manual Sync Now.
- Allow pausing all syncing or pausing a single folder.

## Documentation

- [Product spec](docs/product-spec.md)
- [Phase 1 scope](docs/phase-1.md)
- [Sync model](docs/sync-model.md)
- [GitHub access](docs/github-access.md)
- [macOS permissions](docs/macos-permissions.md)
- [Edge cases](docs/edge-cases.md)
- [Future phases](docs/future-phases.md)

## Working tagline

Automatic version history for your folders.

## Working description

A macOS menu bar app that automatically versions selected folders with GitHub.
