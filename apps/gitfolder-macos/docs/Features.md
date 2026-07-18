# GitFolder (macOS) — Features

What GitFolder does from a user's standpoint. GitFolder is a macOS menu-bar
utility that automatically versions selected local folders to GitHub on an
interval, using system Git under the hood.

This document separates **what ships in the current source** from **what is
modeled, documented, or claimed but not yet built**. Status reflects the code in
`apps/gitfolder-macos/GitFolder/`, not the marketing site or `docs/` product specs
(several of which describe an earlier or aspirational design — see
[Decisions.md](Decisions.md)).

## Shipping today

### Menu-bar presence

- Runs as a menu-bar-only app (`LSUIElement`), no Dock icon and no main window
  on launch (`GitFolderApp`, `Info.plist`).
- Menu-bar dropdown (`MenuBarView`) shows a header summary
  (`N/M folders synced`, or `N folders need attention`) and per-folder status.
- Global actions: **Sync All Now** (⌘S), **Pause / Resume Syncing** (⌘P),
  **Add Folder…** (⌘A), **Settings…** (⌘,), **Quit** (⌘Q).
- Per-folder submenu: status + last-synced time, **Sync Now**, **Open Folder**,
  **Reveal in Finder**, **Copy Repository Web URL**, **Pause/Resume Folder**,
  **Edit Settings…**.

### Adding & configuring folders

- Add a folder through the native macOS folder picker (`NSOpenPanel`); access is
  persisted with a security-scoped bookmark so it survives relaunch and the app
  sandbox (`FolderAccessService`).
- Per folder: a GitHub repository URL, a branch, and a sync interval of
  **5 / 15 / 30 / 60 minutes** (`AddFolderSheet`, `FolderSettingsRow`).
- **Load branches from GitHub** button lists remote branches via `git ls-remote`
  and lets you pick one.
- On add, the flow **tests GitHub access** (`git ls-remote --heads`) before
  saving, then adds and runs a first sync ("Test, Add and Sync").
- Edit, pause/resume, sync-now, and remove folders from the Settings **Folders**
  pane or the menu-bar submenu.

### GitHub authentication

- **Connect GitHub** — GitHub OAuth **device flow**: the app shows a user code,
  opens `github.com`, polls for the token, and looks up the account login
  (`GitHubOAuthService` from GitKit). This is the default and primary path.
- **PAT** — paste a fine-grained personal access token instead
  (`SecureField`), for users who prefer not to use the device flow.
- Token is stored **only in the macOS Keychain**
  (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), never in `config.json`.
- Settings shows connection status and the connected `@login`; **Disconnect**
  clears the Keychain item.

### Automatic & manual sync

- A 60-second in-app `Timer` checks for **due** folders (enabled, has a repo URL,
  and interval elapsed since last successful sync) and syncs them
  (`AppModel.syncDueFolders`).
- Per sync, for each folder: ensure a Git repo (`git init` if needed), ensure the
  `origin` remote and branch, `git status --porcelain`, and if there are changes:
  `git add -A` → snapshot commit → `git pull --rebase origin <branch>` →
  `git push -u origin <branch>` (`GitSyncEngine`).
- Snapshot commit message: `GitFolder snapshot <ISO-8601 timestamp>`.
- No changes → the folder is marked synced with "No changes"; no empty commits.
- **Sync All Now** / per-folder **Sync Now** trigger the same engine manually.
- **Pause all syncing** (global) and **pause individual folders** suppress
  automatic runs; a single global lock (`isSyncing`) prevents overlapping runs.

### Status & errors

- Each folder carries a status (`idle`, `syncing`, `synced`, `paused`, `error`,
  … ) surfaced by **text, icon shape, and color** in both the menu and Settings.
- Failures map to a structured `UserFacingError` (stable code, short title,
  message, and a recovery suggestion) rather than raw Git output
  (`GitSyncError`).

### App-level settings (`SettingsView`)

- **Sync** — pause all, open at login, default interval, manual sync.
- **GitHub** — connect / disconnect / reconnect, account status.
- **Git Identity** — author name and email used for snapshot commits.
- **Folders** — the per-folder editor list.
- **Open at login** via `SMAppService`, with a one-time first-run prompt asking
  whether to enable it (`LoginItemService`, `requestLaunchAtLoginIfNeeded`).

### Data & persistence

- Config stored as JSON at
  `~/Library/Application Support/GitFolder/config.json`, written atomically,
  with `schemaVersion` and **backup-on-invalid** (a corrupt/incompatible file is
  copied to `config.invalid.<timestamp>.json` before reset) (`ConfigStore`).
- No GitFolder account, no backend, no analytics/telemetry — folder contents flow
  only to the user's own GitHub repository.

### SSH (engine only)

- The sync engine supports SSH remotes with a security-scoped SSH-key bookmark
  and a hardened `GIT_SSH_COMMAND`. **This has no UI** and is not reachable in the
  shipping build — see *Planned* below.

## Planned / not yet built

These are modeled in code/`docs/`, claimed in copy, or tracked as tasks, but are
**not** implemented in the current source. See the `GITFOLDER-0xx` cards and
[Decisions.md](Decisions.md).

| Area | State | Notes / task |
|---|---|---|
| **Pre-push safety scan** (secrets, keys, `.env`, large files), `.gitignore` management, first-run content preview | Modeled (`FolderSafetyState`, `SensitivePattern` in `packages/core`; docs Task 9) but **unbuilt** — `git add -A` pushes the whole folder with no warning | GITFOLDER-002 |
| **Conflict / needs-attention states** | Statuses defined and rendered but **never produced**; a failed `pull --rebase` surfaces as generic `error` and can leave the repo mid-rebase (no `--abort`) | GITFOLDER-003 |
| **Change debounce / filesystem watching** | Docs describe a 30s quiet period and "watching"; engine only **polls** every 5–60 min, so it can snapshot half-written files | GITFOLDER-014 |
| **Local logs / Logs window** | `LogEntry` modeled and `logRetentionDays` stored, but **no log store or view** exists | GITFOLDER-022 |
| **SSH auth UI** | Engine + config support SSH; no UI, and `chooseSSHPrivateKey`/`clearSSHPrivateKey` are dead code. `tokenAuthDraft()` silently rewrites stored `authMode` to token | GITFOLDER-019 |
| **Config migration** | Policy documented; not implemented — a differing `schemaVersion` backs up then resets to empty, dropping the folder list | GITFOLDER-017 |
| **Data reset / delete controls** | No "reset GitFolder"; removing a folder leaves the GitFolder-created `.git` history behind locally and on GitHub | GITFOLDER-022 |
| **Least-privilege OAuth scope** | Device flow requests broad classic `repo` scope, contradicting the "fine-grained token" framing | GITFOLDER-009 |
| **Signing / notarization / Store upload** | No pipeline; CI builds with `CODE_SIGNING_ALLOWED=NO`. No `PrivacyInfo.xcprivacy` | GITFOLDER-001, -005, -026 |
| **Sandbox-compatible Git** | App is sandboxed but shells out to system `git`/`ssh` from out-of-container paths — not submittable to the Mac App Store as configured | GITFOLDER-001 |
| Repository picker, create-repo-from-app, GitHub Enterprise, non-GitHub providers | Explicitly out of scope for v1 | `docs/github-access.md`, `docs/future-phases.md` |

## Explicit non-goals (v1)

From `docs/product-spec.md`: GitFolder is **not** a full backup system, a Git
client replacement, a Dropbox/iCloud replacement, a conflict resolver, or a file
restore/diff UI.
