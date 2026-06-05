# Edge Cases

## Folder deleted or moved

Status:

```txt
Folder missing
```

Action:

- Pause syncing for that folder.
- Allow user to locate the folder again.

## Folder permission lost

Status:

```txt
Folder access needed
```

Action:

- Ask user to reselect the folder.

## Git not installed

Status:

```txt
Git not available
```

Action:

- Show setup instructions.
- Phase 1 can depend on system Git.

## GitHub SSH access missing

Status:

```txt
GitHub access failed
```

Action:

- Show SSH/key/repository permission guidance.
- Keep raw Git output in logs.

## Remote has conflicting changes

Status:

```txt
Conflict detected
```

Action:

- Pause folder syncing.
- Do not auto-resolve.
- Show folder in Needs attention state.

## No internet connection

Status:

```txt
Waiting for connection
```

Action:

- Keep local commit if already created.
- Retry push at next interval.

## Huge folders

Status:

```txt
Large folder warning
```

Action:

- Warn before first sync if folder size or file count is high.
- Suggest ignore rules.

## Sensitive files

Risk:

The user may accidentally sync private data, secrets, keys, or large binaries.

Phase 1 should show a warning during setup:

```txt
Only connect folders you are comfortable storing in GitHub.
```

## Binary files

Git can track binary files, but history can become large.

Phase 1 should not block binary files, but later versions could warn about large files.

## App writes while syncing

Risk:

Some files may be temporarily incomplete.

Mitigation:

- Debounce after detecting changes.
- Commit only after a short quiet period.

## Force push

Never force push by default.

## Empty commits

Do not create empty commits.

Use `git status --porcelain` before committing.
