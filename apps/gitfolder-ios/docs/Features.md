# GitFolder iOS — Features

**Status: everything on this page is Planned.** No feature here is built. This is the
intended v1 (and v1.1) scope, phased to match the GITFOLDER-028..035 task cards and the
plan in `Projects/GitKit/Gitfolder/plans/ios-app-plan.md`.

## Scope in one line

Connect GitHub → clone a repo into the app as a real offline filesystem → browse and
manage files → edit Markdown (built-in or Lezin) → commit and push back with token auth.

## Non-goals (v1)

- Merge-conflict resolution UI (conflicts are detected, surfaced, and deferred — same as macOS).
- Providers other than GitHub (GitLab/Bitbucket/Gitea are later).
- Full IDE features (per-language syntax highlighting, diff editor, blame).
- Being a general Files-app replacement (the File Provider extension is v1.1, not v1).
- Real-time collaboration or a GitFolder cloud — local-first, no GitFolder account.

## Phases

### Phase 0 — Engine spike (GITFOLDER-028) — *Planned / de-risk*

Prove the transport before building anything. A standalone package that, using embedded
libgit2, performs on a **device**: clone → edit → commit → pull-rebase → push a real
GitHub repo over HTTPS with a token. Go/no-go on the whole approach. No UI.

Key result to record: is **SwiftGit2** sufficient (authenticated push + conflict-safe
rebase), or must the engine drop to the raw **libgit2 C API**?

### Phase 1 — Shared kit + connect + browse (GITFOLDER-029, GITFOLDER-030) — *Planned*

| Feature | Notes |
|---|---|
| Extract `GitFolderKit` shared package | Platform-agnostic models/config/validation shared with macOS; done **before** UI |
| Connect GitHub (device-flow OAuth) | Reuse macOS `GitHubOAuthService`; token to Keychain |
| Add repository (clone with progress) | Pick repo + branch, clone into app container; foreground, cancellable |
| Repositories list | Connected repos with per-repo sync status |
| Filesystem browser | Hierarchical navigation of the working tree; folders first, then files |
| Per-entry git status badge | untracked / modified / staged / clean |
| Read-only file viewing | QuickLook for binaries; plain-text view for text |

### Phase 2 — Edit & version (GITFOLDER-031) — *Planned*

| Feature | Notes |
|---|---|
| Built-in Markdown editor | Text + rendered preview; Markdown accessory bar; split on iPad |
| Preview rendering | Local CSS in `WKWebView`, no network, light/dark aware |
| File management | Create / rename / move / duplicate / delete files and folders |
| New-file quick actions | New File / New Folder / New Markdown / Import from Files / Import Photo |
| Image insertion | Copies image next to the Markdown (`images/`) and writes a relative link |
| Autosave & draft restore | Debounced autosave; never lose edits on backgrounding |
| Commit + Sync Now | Snapshot commit (`GitFolder snapshot <ISO8601>`) or custom message; pull-rebase then push |
| **Pre-push safety scan** | Warn on `.env`, keys, credentials, DB files, large binaries **before** first commit/push; offer `.gitignore`. Fixes a gap the macOS app has, not ports it |

### Phase 3 — Lezin handoff (GITFOLDER-032, GITFOLDER-033) — *Planned*

| Feature | Notes |
|---|---|
| Confirm Lezin contract (chore) | URL scheme, declared UTIs, open-in-place support — coordinate with the Lezin project |
| Detect Lezin | `UIApplication.canOpenURL` on the Lezin scheme (needs `LSApplicationQueriesSchemes`) |
| "Edit in Lezin" | Primary action for `.md`/`.markdown` when Lezin is present |
| Best-effort open-in-place | Security-scoped open-in-place URL so Lezin edits the original, round-tripping into the repo |
| Copy fallback | Clearly labeled "Open in Lezin (copy)" stopgap when open-in-place can't be guaranteed |
| Default-editor setting | Built-in vs Lezin |
| Built-in editor fallback | Always available when Lezin is absent or by choice |

### Phase 4 — Background sync & polish (GITFOLDER-034) — *Planned*

| Feature | Notes |
|---|---|
| Background sync | `BGAppRefreshTask` / `BGProcessingTask`; opportunistic pull/commit/push — never guaranteed |
| Commit-on-background | Commit + attempt push in the short `beginBackgroundTask` window |
| Sync interval as a target | Honor `syncIntervalMinutes` as a goal, not a promise |
| Privacy manifest | `PrivacyInfo.xcprivacy` (Keychain/UserDefaults reasons, no tracking) — required |
| Onboarding & empty states | Proper first-run and empty-repo flows |
| iPad polish | Two/three-column `NavigationSplitView`; split source/preview |

### v1.1 — File Provider extension (GITFOLDER-035) — *Planned*

| Feature | Notes |
|---|---|
| Git-backed File Provider | `NSFileProviderReplicatedExtension` over the libgit2 working tree |
| Repos in Files app | Materialize on demand; report git status as metadata where possible |
| In-place Lezin round-trip | External writes enqueue a commit; becomes the first-class Lezin path |
| App group | Share repo container + Keychain between app and extension |

### Later (unscheduled)

History/restore (mirrors macOS Future Phase 4), repo picker from the GitHub repo list,
more providers, and a conflict-resolution UI.
