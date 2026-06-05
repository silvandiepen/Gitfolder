# Sync Model

## Goal

Create automatic snapshot commits for selected folders and push them to GitHub.

## Default behavior

Every configured interval, GitFolder checks each enabled folder.

If there are no changes, it does nothing.

If there are changes, it creates one snapshot commit and pushes it.

## Basic algorithm

```txt
For each enabled folder:
  1. Check that the folder still exists.
  2. Check that the app has file access.
  3. Check that Git is available.
  4. Check whether the folder is a Git repository.
  5. If needed, initialize Git and connect remote.
  6. Inspect repository state.
  7. Stop if merge, rebase, conflict, or unsafe divergence exists.
  8. Fetch remote state.
  9. Check whether local changes exist.
  10. If no changes, mark as synced/no changes.
  11. If changes exist, wait briefly.
  12. Check status again.
  13. Stage changes.
  14. Create a snapshot commit.
  15. Push to remote.
  16. Update status.
```

Important: do not make a local snapshot commit before checking whether the repository is already in an unsafe state. If the remote changed in a way GitFolder cannot safely handle, pause the folder and ask for attention.

## Commands

Check changes:

```bash
git status --porcelain
```

Stage changes:

```bash
git add .
```

Commit:

```bash
git commit -m "GitFolder snapshot: 2026-06-05 10:24"
```

Pull before push:

```bash
git pull --rebase origin main
```

Push:

```bash
git push origin main
```

## Snapshot commit message

Default:

```txt
GitFolder snapshot: YYYY-MM-DD HH:mm
```

Example:

```txt
GitFolder snapshot: 2026-06-05 10:24
```

## Debounce rule

When changes are detected, GitFolder should wait briefly before committing.

Reason: some apps write files in multiple steps. Committing instantly can catch half-written files.

Suggested delay: 30 seconds.

## Safety rules

GitFolder must never:

- Silently delete remote files.
- Silently overwrite local files.
- Auto-resolve merge conflicts.
- Force push by default.
- Continue syncing a folder with unresolved conflicts.

## Conflict behavior

If pull/rebase fails:

1. Mark folder as `conflict`.
2. Pause syncing for that folder.
3. Show a clear status message.
4. Keep the technical Git output in logs.

User-facing message:

```txt
Sync paused: this folder has changes that conflict with GitHub.
```

## Recommended default `.gitignore`

```gitignore
.DS_Store
*.tmp
*.swp
*.log
.Trashes
.Spotlight-V100
.fseventsd
node_modules/
dist/
.cache/
```
