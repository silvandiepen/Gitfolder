# GitKanban iOS — Agent Instructions

Read the root [`../../AGENTS.md`](../../AGENTS.md) first; this file adds GitKanban-iOS-specific
rules. Global hard rules and conventions are not restated here.

## Status

**Planned — Phase 2, the furthest-out target.** This directory is **docs/spec only; there is no code
here yet.** Do not scaffold an Xcode target, add sources, or mark anything as implemented. Everything
about this app is Planned/Proposed until GitKanban macOS (Phase 1) and the iOS git engine exist.

## What this app depends on (do not duplicate)

- **Git transport:** the shared iOS **`Libgit2Engine`** in [`swift/GitKit`](../../swift/GitKit/) —
  shared with GitFolder iOS, since iOS has no shell and cannot run the macOS subprocess engine. It is
  unbuilt; it is de-risked by the `spikes/libgit2-ios/` spike (`GITKIT-128`). **Do not build a second
  git engine or a new git abstraction** — conform to the existing `GitEngine` protocol.
- **Board schema + logic:** [`@gitkit/gitkanban-core`](../../packages/gitkanban-core/). **TypeScript
  is the source of truth**; Swift mirrors it. **Do not build a second board/schema abstraction** —
  reuse the shared one, as macOS does.
- **Board UI:** produced by GitKanban macOS as a platform-agnostic layer, intended to run on iOS
  unchanged. iOS adds touch navigation/drag chrome around it, not a reimplementation.

## Where the plan and tasks live

- **Plan:** `project-assets/GitKit/GitKanban/plan/` — `platforms-and-git.md` (the iOS git story),
  `architecture.md`, `implementation-plan.md` (Phase 2). Local detail in [`docs/`](./docs/).
- **Tasks:** the `GitKit` board, `project-assets/Tasks/GitKit/`, epic **`gitkanban-ios`**. The epic
  is defined; no cards are open in it yet.

## When writing docs here

- Never present planned work as done; never fabricate concrete APIs. Where the plan is silent, write
  **Open**. Record any judgment call in [`docs/Decisions.md`](./docs/Decisions.md) as Proposed/Open.
- Do not modify code or other apps' files from this directory.
