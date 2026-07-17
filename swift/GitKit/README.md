# GitKit (Swift)

The shared Swift package for GitKit's native apps (GitFolder, GitKanban).

**Status: scaffold.** Today it defines the `GitEngine` protocol and its supporting types.
The plan is to move GitFolder's inline services into this package so both apps share one
implementation instead of forking:

- `GitEngine` — `clone / pullRebase / commit / push / status / fileHistory`
  - `ShellGitEngine` (macOS, subprocess `git` — from GitFolder's `GitRunner`)
  - `Libgit2Engine` (iOS, embedded libgit2 — new)
- `ConfigStore`, `KeychainService`, `GitHubOAuthService`, `FolderAccessService`
  (moved out of `apps/native-macos`)
- `MarkdownStore` — files ⇄ cards, mirroring `@gitkit/gitkanban-core`

The UI never touches git or files directly; it goes through `GitEngine` and `MarkdownStore`.
That boundary is what lets one board UI run on macOS shell-git and iOS libgit2 unchanged.

See `project-assets/GitKanban/plan/architecture.md` and `platforms-and-git.md`.
