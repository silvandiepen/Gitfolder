# GitKanban (macOS) — Agent Instructions

Read the root [`../../AGENTS.md`](../../AGENTS.md) first; this file adds GitKanban-macOS-specific
rules. It does not restate the global hard rules — they still apply.

## What this app is

A native macOS kanban board whose data source is a git repo of markdown files. Today the app
**builds and runs a working read/write board**: `GitKanban/App/GitKanbanApp.swift`,
`GitKanban/App/AppModel.swift` (the single UI-facing `@Observable` state object), and
`GitKanban/Board/BoardView.swift` connect to GitHub, clone a repo the app owns, and render, edit,
move, reorder, delete, filter, search, and sync a board of markdown cards. Every mutation commits
and pushes. See [`docs/Architecture.md`](./docs/Architecture.md) for what exists vs. what is
planned, and [`docs/Features.md`](./docs/Features.md) / [`docs/Decisions.md`](./docs/Decisions.md)
for the rest.

## Rules specific to this app

- **Board logic is owned by `packages/gitkanban-core` (TypeScript is the source of truth).** Change
  the contract — schema, inheritance, rank keys, validation, field sources — **there first**, then
  mirror it in Swift. Never fork or re-invent the board logic in Swift; the Swift models mirror the
  TS package field-for-field so the macOS and (future) iOS parsers can't drift.
- **The canonical board format is `/Users/silvandiepen/Projects/Tasks/README.md`.** GitKanban
  renders a board of exactly that shape: **lanes are folders**, a card's `status` must match its
  lane folder, and config lives in root/project README frontmatter with inheritance. Treat it as
  the authoritative schema. Moving a card means moving its file into the new lane folder **and**
  updating `status`.
- **Git and board parsing come from `swift/GitKit`,** not inline copies — `GitEngine`/
  `ShellGitEngine`, `BoardStore`/`BoardMarkdown`/`BoardModel`/`BoardInheritance`, `RemoteBoardStore`,
  `KeychainService`, `GitHubOAuthService`, `GitHubReposService`, `CardText`. Apps depend on
  packages, never on each other or on GitFolder.
- **Preserve unknown frontmatter keys.** Writes must round-trip untouched keys (a read-then-write
  of an unchanged card should be a zero diff). External writers (sills, CI, agents) add fields the
  app does not model; do not drop them. NB: card writes currently compose frontmatter by hand in
  `AppModel`; routing them through GitKit/Yams and hardening round-trip fidelity is tracked on the
  board — keep that guarantee in mind when touching the write path.
- **XcodeGen only.** Never hand-edit the `.xcodeproj`. Edit `project.yml`, then regenerate:
  `cd apps/gitkanban-macos && xcodegen generate`.

## Where the plan and tasks live

- **Plan / spec:** `/Users/silvandiepen/Projects/GitKit/GitKanban/plan/` (`README.md`,
  `product-spec.md`, `data-model.md`, `sync-model.md`, `architecture.md`, `platforms-and-git.md`,
  `implementation-plan.md`, `phase-1.md`, `risks-and-open-questions.md`).
- **Task board:** `/Users/silvandiepen/Projects/Tasks/GitKit/` — cards with a `GITKIT-###` id and
  `epic: gitkanban-macos` (app) or `gitkanban-core` (contract). Follow the board contract when
  mutating cards.

## Commands

```bash
npm run gitkanban:core:test                      # test the board logic (TS source of truth)
npm run gitkanban:webview:build                  # rebuild the markdown-renderer webview bundle
npm run gitkanban:run                            # build + run the macOS app (scripts/run.sh)
cd apps/gitkanban-macos && xcodegen generate     # (re)generate the Xcode project
```
