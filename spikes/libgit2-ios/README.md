# libgit2-ios spike (GITKIT-128)

**Goal (one question):** can an iOS app do real git — **clone, commit, pull-rebase, and push over
HTTPS with an OAuth/PAT token** — using embedded libgit2? iOS has no shell and no `git` binary, so
the macOS `GitRunner`/subprocess engine does not port. This spike answers the make-or-break unknown
before any UI or shared-package work, per `GitKanban/plan/platforms-and-git.md` and
`GitKanban/plan/gitfolder-ios-app.md` (Section 4).

Board card: **GITKIT-128** (`gitkit-swift` epic). This directory is intentionally standalone so it
cannot collide with the in-progress `swift/GitKit` extraction (GITKIT-005/006).

## ⚠️ Status: scaffold, not yet built

Authored in a headless Linux session with **no Swift / libgit2 / iOS SDK**, so **nothing here has
been compiled or run.** It is a starting point to open on a Mac. What is durable regardless of
toolchain: the `GitEngine` protocol (`Sources/GitKitEngineSpike/GitEngine.swift`) and the libgit2
**C-API call sequences** documented in `Libgit2Engine.swift`. The SwiftGit2 calls are a first draft
to reconcile against the pinned fork.

## Run it (on a Mac)

```bash
cd spikes/libgit2-ios
# a throwaway repo + a fine-grained token scoped to contents:write on THAT repo only
export GITKIT_SPIKE_REPO="https://github.com/<you>/gitkit-spike-throwaway.git"
export GITKIT_SPIKE_TOKEN="<token>"
swift run libgit2-spike-cli
# then, the real question: build the same package for an iOS target and run it on a device/simulator
```

Never commit a token. Revoke it after the run.

## Acceptance checklist (maps to GITKIT-128)

- [ ] `swift build` resolves SwiftGit2 and compiles for macOS.
- [ ] The package builds for an **iOS** target (device + simulator arch) — the real test; note binary size.
- [ ] **clone** a private repo over HTTPS with the token succeeds.
- [ ] **commit** a local edit succeeds (wire `stageAllAndCommit`).
- [ ] **pull --rebase** integrates remote changes and, on conflict, **aborts to a clean tree** (never mid-rebase) — the iOS mirror of audit finding EXP-0002 / GITKIT-013.
- [ ] **push** over HTTPS with the token succeeds ← historically the weakest wrapper area; the key result.
- [ ] Record: SwiftGit2 sufficient, or drop to the libgit2 C API? Feed the answer into the shared `GitEngine` (GITKIT-006) and the real `Libgit2Engine` (`gitkit-swift` epic).

## Decision this spike feeds

- **If SwiftGit2 does authenticated push + conflict-safe rebase on iOS:** adopt it for `Libgit2Engine`.
- **If not:** implement `Libgit2Engine` directly on the libgit2 C API (a `Clibgit2` system-library or
  a prebuilt xcframework), using the C sequences already documented in `Libgit2Engine.swift`.
- Either way, the iOS engine conforms to the **same `GitEngine`** as macOS's `ShellGitEngine`
  (GITKIT-006), so the app layer is platform-agnostic. Do **not** build a second engine abstraction.

## What this spike is NOT

No UI, no board rendering, no file browser, no Lezin handoff — those are GITKIT-130+ and depend on the
shared package. This proves the transport only.
