# GitFolder for iOS

**Status: Planned (no code yet).** This directory is a docs/spec home for the iOS
counterpart of the shipping GitFolder macOS app. Nothing here is built.

GitFolder for iOS is a **git-backed folder browser and Markdown editor** for iPhone
and iPad. The user connects a GitHub account, clones a repository into the app so it
behaves like a real offline filesystem, browses and manages files, edits Markdown
(built-in editor, or hand off to **Lezin** when installed), and pushes every change
back as a git commit.

Where the macOS app is a background menu-bar sync utility that shells out to the
system `git` binary, the iOS app is a foreground file manager — a different app shape
with a fundamentally different git engine.

## The make-or-break unknown

> **iOS has no `git` binary and no `Process`/subprocess API.**

The macOS engine shells out to `git`; none of that ports. iOS must run git **in-process
via embedded libgit2** and push over **HTTPS with a GitHub token** (no SSH on iOS). The
single highest-risk question the whole app depends on is:

> Can an iOS app **clone, commit, pull-rebase, and push** a real GitHub repo over HTTPS
> with a token, using embedded libgit2, on a device?

A Phase 0 spike (see below) exists to answer this before any UI work begins.

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
