# GitKanban iOS — Agent Instructions

Read the root [`../../AGENTS.md`](../../AGENTS.md) first; this file adds GitKanban-iOS-specific
rules. Global hard rules and conventions are not restated here.

## Status

**Working read/write board over an API transport.** The app is scaffolded and builds for the iOS
Simulator: connect (GitHub / GitLab.com / self-hosted GitLab via a personal access token) → repo
picker → board load → create/edit/move/delete cards. Transport is the provider **REST API via
[git-pont](../../../_libs/git-pont)** (no local clone, no `git` binary), **not** the
previously-planned `libgit2` engine — that gate is superseded and no `Libgit2Engine` exists.
Board parsing/model stays in shared `swift/GitKit` (`RemoteBoardStore` + `BoardFileSource`); iOS
must not fork the schema or the board logic. An embedded-libgit2 offline mode is a possible later
addition, not a prerequisite. Writes are currently blind (last-writer-wins); reorder, per-card
history, offline, and conflict handling are not built yet.

## What this app depends on (do not duplicate)

- **Git transport:** git-pont's `GitProvider` (`GitPontCore` + `GitPontGitHub`/`GitPontGitLab`),
  reached through `GitPontFileSource`, which conforms to GitKit's **`BoardFileSource`**. iOS has no
  shell and cannot run the macOS subprocess engine. **Do not build a git engine or call
  `GitEngine`** — the board is loaded/written through `BoardFileSource` + `RemoteBoardStore`.
- **Board schema + logic:** [`@gitkit/gitkanban-core`](../../packages/gitkanban-core/). **TypeScript
  is the source of truth**; Swift mirrors it (via `swift/GitKit`). **Do not build a second
  board/schema abstraction** — reuse the shared one, as macOS does.
- **Board UI:** the iOS UI is **bespoke SwiftUI** written in this app (`RootView`, `BoardScreen`,
  `CardSheets`), not imported from macOS. Keep it thin over the shared model; do not fork board
  logic into the views.

## Where the plan and tasks live

- **Plan:** `/Users/silvandiepen/Projects/GitKit/GitKanban/plan/` — `platforms-and-git.md` (the iOS
  git story), `architecture.md`. Local detail in [`docs/`](./docs/).
- **Tasks:** the `GitKit` board, `/Users/silvandiepen/Projects/Tasks/GitKit/`, epic
  **`gitkanban-ios`**.

## When writing docs here

- Never present planned work as done; never fabricate concrete APIs. Where the plan is silent, write
  **Open**. Record any judgment call in [`docs/Decisions.md`](./docs/Decisions.md).
- Do not modify code or other apps' files from this directory.
