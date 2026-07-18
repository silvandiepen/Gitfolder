# GitKanban (macOS) — Architecture

How GitKanban is built and planned. The theme throughout: **the board contract is owned in
TypeScript, the git engine is shared Swift, and the app is a thin, replaceable UI on top.** This
document is explicit about what **Exists** on disk today versus what is **Planned** / tracked on
the GitKit board.

---

## What exists vs. what is planned

| Layer | Where | Status |
|---|---|---|
| Board contract (card + config format) | `project-assets/Tasks/README.md` | **Exists** (canonical, live board) |
| Board logic (schema, inheritance, rank, validation) | `packages/gitkanban-core` (TS) | **Exists** — built + tested |
| Shared git engine + services | `swift/GitKit` | **Partial** — `GitEngine` protocol, `ShellGitEngine`, `KeychainService`, `GitHubOAuthService` exist; `MarkdownStore`, `ConfigStore`, `FolderAccessService` pending |
| Swift board model (`BoardStore`/`BoardMarkdown`, config) mirroring core | `swift/GitKit` | **Exists** — GITKIT-009, in the shared package, tested |
| App shell + board UI | `apps/gitkanban-macos/GitKanban/` | **Exists (read-only)** — `GitKanbanApp`, `BoardViewModel`, `BoardView` build and render a board. Editing / drag-to-move / git-sync **Planned** |

> The GitKit task board tracked the Swift board model (GITKIT-009) and the board UI render
> (GITKIT-010) as deliverables; both are merged. The Swift board model lives in `swift/GitKit`, and
> `apps/gitkanban-macos/GitKanban/` builds a read-only board UI on top of it. Card editing,
> drag-to-move, and git commit/sync are still Planned. Do not assume Swift APIs beyond what
> `swift/GitKit/Sources/GitKit/` and `apps/gitkanban-macos/GitKanban/` actually contain.

---

## Two contracts, two layers

GitKanban is deliberately split so the platform-specific parts (UI, git transport) can change
without touching the board's meaning.

### 1. `packages/gitkanban-core` — the TypeScript contract (Exists)

The platform-agnostic source of truth. Modules:

| Module | Responsibility |
|---|---|
| `types.ts` | `Lane`, `User`, `Epic`, `Priority`, `BoardConfig`, `ProjectConfig`, `EffectiveConfig`, `ParsedCard`, `CardFields`, `FieldSource` |
| `frontmatter.ts` | Parse/serialize markdown frontmatter, **preserving unmodelled keys** (`yaml` lib) |
| `inheritance.ts` | `resolveEffectiveConfig(root, project)` — lanes **replace**, vocabularies **merge** |
| `rank.ts` | Fractional rank keys (`rankBetween`, `firstRank`, `ranksAfter`, `initialRanks`) over `fractional-indexing` |
| `card.ts` | `getCardFields` / `resolveCardFields`, `laneForCard`, `compareCards`, `groupIntoColumns` |
| `bodyfields.ts` | `resolveBodySectionFields` — read fields from a markdown body section (legacy boards) |
| `validation.ts` | `validateCard(config, card)` against the effective config |

The **Swift side mirrors this package** and is tested against its shared fixtures so the two
parsers cannot drift.

### 2. `swift/GitKit` — the shared Swift engine (Partial)

The one package both native apps depend on. `apps/gitkanban-macos/project.yml` already declares the
dependency (`packages: GitKit: path: ../../swift/GitKit`). Present in
`swift/GitKit/Sources/GitKit/`:

- `GitEngine` (protocol) — `clone`, `pullRebase`, `commit`, `push`, `status`,
  `fileHistory(at:file:limit:)`. **The only thing that knows git.**
- `ShellGitEngine` — macOS implementation shelling out to `git` (ported from GitFolder's
  `GitRunner`), with `GitProcessRunner`.
- `GitTypes` (`GitAuth`, `PullResult`, `RepoStatus`, `CommitInfo`), `GitEngineError`.
- `KeychainService`, `GitHubOAuthService` (device-flow OAuth).

Pending extraction from GitFolder (tracked GITKIT-005): `FolderAccessService`, `ConfigStore`, and
`MarkdownStore` (files ⇄ cards, mirroring `gitkanban-core`). `Libgit2Engine` (iOS) is Phase 2.

---

## Planned app structure

From the app README — the SwiftUI target sources land under `GitKanban/` (see `project.yml`,
`sources: GitKanban`):

```txt
GitKanban/
  App/       GitKanbanApp (entry), AppModel (single UI-facing @Observable state)
  Models/    Card, Board, Column, config — mirror @gitkit/gitkanban-core
  Services/  MarkdownStore, BoardSyncEngine — built on GitKit's GitEngine
  Board/     columns, drag/drop, card editor, history view
  Views/
```

Convention (root AGENTS.md): `AppModel` is the single UI-facing state object; domain/services stay
UI-agnostic so the same layer can later back iOS unchanged.

---

## Module boundaries and data flow

The UI mutates **domain objects only**. `MarkdownStore` is the only thing that knows the file
format; `GitEngine` is the only thing that knows git. That double boundary is what lets one board
UI run on macOS shell-git and (later) iOS libgit2 unchanged.

```txt
        ┌──────────────────────────────────────────────┐
        │  SwiftUI board UI  (columns · card editor ·   │   Partial — columns render
        │  drag/drop · history view)                    │   (read-only); editor/drag/
        └───────────────┬──────────────────────────────┘   history Planned
                        │ reads/writes domain objects only
                        ▼
        ┌──────────────────────────────────────────────┐
        │  Domain: Board · Column · Card · Config       │   Exists (Swift mirror in
        │  (mirrors @gitkit/gitkanban-core)             │   swift/GitKit / GITKIT-009)
        └───────┬───────────────────────────┬──────────┘
                │                            │
                ▼                            ▼
   ┌─────────────────────────┐   ┌──────────────────────────────┐
   │ MarkdownStore           │   │ BoardSyncEngine              │   Planned
   │ files ⇄ cards, using    │   │ orchestrates commit-per-     │
   │ core schema rules       │   │ action, pull --rebase / push │
   │ (Yams frontmatter)      │   │ + status states              │
   └───────────┬─────────────┘   └───────────────┬──────────────┘
               │                                  │ calls only the protocol
               │                                  ▼
               │                    ┌──────────────────────────────┐
               │                    │ GitEngine (protocol)         │   Exists
               │                    │  ├─ ShellGitEngine (macOS)    │   Exists
               │                    │  └─ Libgit2Engine (iOS)       │   Planned (Phase 2)
               │                    └───────────────┬──────────────┘
               ▼                                    ▼
        ┌──────────────────────────────────────────────────────────┐
        │  Repo of markdown files (the board) — local git clone     │
        │  card files + README-frontmatter config; git is the store │
        └──────────────────────────────────────────────────────────┘
```

Read path: repo files → `MarkdownStore` parses each card (`parseCard`) and the config →
`resolveEffectiveConfig` → `groupIntoColumns` → domain `Board`/`Column`/`Card` → board UI.

Write path: a UI action mutates a domain card → `MarkdownStore` serializes just that card
(`serializeCard`, minimal diff) → `BoardSyncEngine` commits one logical action → `pull --rebase`
then `push` via `GitEngine`. A column move = editing `status`; a reorder = minting one `order`
rank key — each a single-line diff in a single file (see [Decisions.md](./Decisions.md) §3, §6).

---

## Build & project generation

- **XcodeGen.** The Xcode project is generated from `project.yml` — never hand-edit the
  `.xcodeproj`. Regenerate with `cd apps/gitkanban-macos && xcodegen generate`.
- **Target:** `GitKanban`, macOS 14.0+, bundle id `app.hakobs.gitkanban`, sandboxed
  (`app-sandbox`, `network.client`, `files.user-selected.read-write`, `bookmarks.app-scope`),
  hardened runtime, category `developer-tools`. A `GitKanbanTests` unit-test bundle is defined.
- **Dependency:** the `GitKit` Swift package (`../../swift/GitKit`).
- **Core tests:** `npm run gitkanban:core:test` runs the TypeScript board-logic suite (Vitest).
- **CI:** the TS contract tests run today; Swift CI (`swift-gitkit.yml`, and a gitkanban-macos
  build) is added as the app target materializes.

---

## Platform trajectory

macOS (Phase 1) shells out to `git`. iOS (Phase 2) cannot — no shell, no `git` binary — so it uses
an embedded `Libgit2Engine` (HTTPS + OAuth token), with the GitHub HTTP API as a possible
fast-start fallback. The `GitEngine` protocol is what makes that swap invisible to the board UI.
Details in `project-assets/GitKit/GitKanban/plan/platforms-and-git.md`.
