# GitFolder for iOS

**Status: Building (v0.1).** A working SwiftUI app under `GitFolder/` that connects to a
git provider, browses a repository's files, and edits/creates/deletes them — each change
committed and pushed. Builds and runs on the simulator and on device (app id
`app.hakobs.gitfolder`).

GitFolder for iOS is a **git-backed folder browser and Markdown editor** for iPhone
and iPad. The user connects a GitHub (or GitLab) account with a personal access token,
picks a repository, browses and manages its files, edits Markdown (built-in editor with
a rendered preview), and every save is a git commit pushed back to the remote.

## How it talks to git (the make-or-break, resolved)

> **iOS has no `git` binary and no `Process`/subprocess API.**

The macOS engine shells out to `git`; none of that ports. Rather than embed libgit2, the
iOS app uses **[git-pont](https://github.com/silvandiepen/git-pont)** — the hosted
provider REST API (GitHub/GitLab) over HTTPS with a token. There is **no local clone**:
directory listings, file reads, and writes (`commitFile` / `deleteFile`, one commit each,
pushed immediately) all go through the provider API. This is the same transport the
GitKanban iOS app uses, and it sidesteps the libgit2 question entirely.

The original libgit2 offline-clone plan below is superseded by the git-pont approach for
v0.1; a true offline clone can return later as an enhancement.

## Where the plan and tasks live

| What | Where |
|---|---|
| Full product & implementation plan | `Projects/GitKit/Gitfolder/plans/ios-app-plan.md` |
| iOS git-transport rationale | `Projects/GitKit/GitKanban/plan/platforms-and-git.md` |
| libgit2 iOS spike (branch, not in working tree) | `spikes/libgit2-ios/` on `origin/claude/gitfolder-audit-ios-plan-w4ayyo` |
| Shared Swift package (the `GitEngine` both platforms share) | `swift/GitKit/README.md` |
| macOS app this mirrors | `apps/gitfolder-macos/README.md` |

### Task cards (GITFOLDER-028 .. 035)

| Card | Phase |
|---|---|
| GITFOLDER-028 | Phase 0 — libgit2 engine spike (clone/commit/push from device) |
| GITFOLDER-029 | Phase 1 — extract shared `GitFolderKit` Swift package |
| GITFOLDER-030 | Phase 1 — GitHub connect, add repo (clone), filesystem browser |
| GITFOLDER-031 | Phase 2 — file management, Markdown editor, commit/sync, pre-push safety |
| GITFOLDER-032 | iOS — confirm the Lezin integration contract (chore) |
| GITFOLDER-033 | Phase 3 — Lezin handoff for Markdown editing |
| GITFOLDER-034 | Phase 4 — background sync, privacy manifest, onboarding/iPad polish |
| GITFOLDER-035 | v1.1 — git-backed File Provider extension (in-place Lezin round-trip) |

See [`docs/Features.md`](docs/Features.md), [`docs/Architecture.md`](docs/Architecture.md),
[`docs/Decisions.md`](docs/Decisions.md), and [`AGENTS.md`](AGENTS.md).
