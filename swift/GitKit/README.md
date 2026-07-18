# GitKit (Swift)

The shared Swift package for GitKit's native apps (GitFolder, GitKanban).

**Status: in progress.** The engine and two shared services are implemented; the rest is being
moved out of GitFolder as it can be verified.

Implemented:
- `GitEngine` — `clone / pullRebase / commit / push / status / fileHistory`
  - ✅ `ShellGitEngine` (macOS, subprocess `git` — ported from GitFolder's `GitRunner`) + tests
  - `Libgit2Engine` (iOS, embedded libgit2 — new) — pending
- ✅ `KeychainService` — generic keychain item store (service/account configurable)
- ✅ `GitHubOAuthService` — GitHub device-flow OAuth (Foundation-only; macOS + iOS)

Pending extraction from `apps/gitfolder-macos` (need an Xcode build to verify the app still compiles):
- `FolderAccessService` (AppKit + security-scoped bookmarks; entangled with the app's model)
- `ConfigStore` (per-app model — GitFolder folders vs GitKanban boards)
- `MarkdownStore` — files ⇄ cards, mirroring `@gitkit/gitkanban-core`

Note: the shared services currently live *alongside* GitFolder's own copies (additive, so GitFolder
is untouched). De-duplicating — repointing GitFolder at `GitKit` and deleting its inline copies — is
the Xcode-verified follow-up.

The UI never touches git or files directly; it goes through `GitEngine` and `MarkdownStore`.
That boundary is what lets one board UI run on macOS shell-git and iOS libgit2 unchanged.

See `project-assets/GitKit/GitKanban/plan/architecture.md` and `platforms-and-git.md`.
