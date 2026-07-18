# GitKanban (macOS) — Agent Instructions

Read the root [`../../AGENTS.md`](../../AGENTS.md) first; this file adds GitKanban-macOS-specific
rules. It does not restate the global hard rules — they still apply.

## What this app is

An **in-development scaffold**. Today `apps/gitkanban-macos/` contains only `project.yml` and
`README.md`; the SwiftUI board app is Phase 1 work not yet in this directory. It is a native macOS
kanban board whose data source is a git repo of markdown files. See
[`docs/Architecture.md`](./docs/Architecture.md) for what exists vs. what is planned, and
[`docs/Features.md`](./docs/Features.md) / [`docs/Decisions.md`](./docs/Decisions.md) for the rest.

## Rules specific to this app

- **Board logic is owned by `packages/gitkanban-core` (TypeScript is the source of truth).** Change
  the contract — schema, inheritance, rank keys, validation, field sources — **there first**, then
  mirror it in Swift. Never fork or re-invent the board logic in Swift; the Swift models mirror the
  TS package field-for-field so the macOS and (future) iOS parsers can't drift.
- **The canonical board format is `project-assets/Tasks/README.md`.** GitKanban renders a board of
  exactly that shape (card frontmatter + root/project config with inheritance). Treat it as the
  authoritative schema.
- **Git and services come from `swift/GitKit`,** not inline copies — `GitEngine`/`ShellGitEngine`,
  `KeychainService`, `GitHubOAuthService` (and, as extracted, `MarkdownStore`, `ConfigStore`,
  `FolderAccessService`). Apps depend on packages, never on each other or on GitFolder.
- **Preserve unknown frontmatter keys.** Writes must round-trip untouched keys (a read-then-write
  of an unchanged card is a zero diff). External writers (sills, CI, agents) add fields the app does
  not model; do not drop them.
- **XcodeGen only.** Never hand-edit the `.xcodeproj`. Edit `project.yml`, then regenerate:
  `cd apps/gitkanban-macos && xcodegen generate`.

## Where the plan and tasks live

- **Plan / spec:** `project-assets/GitKit/GitKanban/plan/` (`README.md`, `product-spec.md`,
  `data-model.md`, `sync-model.md`, `architecture.md`, `platforms-and-git.md`,
  `implementation-plan.md`, `phase-1.md`, `risks-and-open-questions.md`).
- **Task board:** `project-assets/Tasks/GitKit/` — cards with a `GITKIT-###` id and
  `epic: gitkanban-macos` (app) or `gitkanban-core` (contract). Follow the board contract when
  mutating cards.

## Commands

```bash
npm run gitkanban:core:test                      # test the board logic (TS source of truth)
cd apps/gitkanban-macos && xcodegen generate     # (re)generate the Xcode project
```
