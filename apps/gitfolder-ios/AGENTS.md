# AGENTS — GitFolder iOS

Read the root `../../AGENTS.md` first; this file adds GitFolder-iOS-specific rules.

- **Docs/spec only — no code yet.** This app is **Planned**. This directory currently
  holds documentation only. Never describe planned features as done, and never fabricate
  concrete APIs beyond what the plan and spike actually sketch. Where something is
  unknown, say so.

- **The transport spike gates all UI work.** No UI or shared-package feature work starts
  until the Phase 0 libgit2 spike (GITFOLDER-028, `spikes/libgit2-ios/` on branch
  `origin/claude/gitfolder-audit-ios-plan-w4ayyo`) proves clone/commit/pull-rebase/push
  over HTTPS with a token on a device. The whole app depends on that result.

- **One engine abstraction, not two.** The iOS engine must conform to the **same
  `GitEngine` protocol** as the macOS `ShellGitEngine` (in `swift/GitKit`). Do **not**
  build a second git abstraction for iOS — implement `Libgit2Engine` against the shared
  protocol.

- **Extract `GitFolderKit` before UI.** Domain/config/validation is shared with macOS
  through the `GitFolderKit` package (GITFOLDER-029). Do not hand-copy models into iOS —
  that is the divergence trap the audit called out.

- **Where the plan and tasks live:**
  - Plan: `Projects/GitKit/Gitfolder/plans/ios-app-plan.md`
  - Transport rationale: `GitKanban/plan/platforms-and-git.md`
  - Spike: `spikes/libgit2-ios/` (branch above)
  - Tasks: GITFOLDER-028 .. 035 (see `README.md` for the phase mapping)
  - Local docs: `docs/Features.md`, `docs/Decisions.md`, `docs/Architecture.md`
