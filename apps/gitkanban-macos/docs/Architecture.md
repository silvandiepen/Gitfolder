# GitKanban (macOS) — Architecture

How GitKanban is built. The theme throughout: **the board contract is owned in TypeScript, the git
engine and board parsing are shared Swift, and the app is a thin UI + state layer on top.** This
document is explicit about what **Exists** on disk today versus what is **Planned** / tracked on
the GitKit board.

---

## What exists vs. what is planned

| Layer | Where | Status |
|---|---|---|
| Board contract (card + config format) | `/Users/silvandiepen/Projects/Tasks/README.md` | **Exists** (canonical, live board) |
| Board logic (schema, inheritance, rank, validation) | `packages/gitkanban-core` (TS) | **Exists** — built + tested |
| Shared git engine + services | `swift/GitKit` | **Exists** — `GitEngine`, `ShellGitEngine`, `GitProcessRunner`, `KeychainService`, `GitHubOAuthService`, `GitHubReposService` |
| Swift board model + parsing | `swift/GitKit` | **Exists** — `BoardStore`, `BoardMarkdown`, `BoardModel`, `BoardInheritance`, `RemoteBoardStore`, `CardText` |
| App shell + board UI (read/write) | `apps/gitkanban-macos/GitKanban/` | **Exists** — connect, own-checkout clone, render, create/edit/move/reorder/delete, filter/search, per-card history, commit+push |
| Background interval sync + conflict UI | `apps/gitkanban-macos/GitKanban/` | **Planned** — writes commit+push immediately; last-writer-wins |
| Fractional rank keys in the app | `apps/gitkanban-macos/GitKanban/` | **Planned** — the app uses an integer `order` today (core has `rank.ts`) |
| Swift test target | `apps/gitkanban-macos/project.yml` | **Planned** — no `GitKanbanTests` target yet |

> GITKIT-009 (Swift board model) and GITKIT-010 (board render) shipped in `swift/GitKit` and the
> app. GITKIT-011 (editing/move), GITKIT-012 (commit+push), and GITKIT-013 (history) also shipped,
> alongside a large amount of unplanned surface (GitHub connect + own-the-checkout, project/task
> CRUD, editable settings, markdown webview, filters/search/list/multi-select). Do not assume Swift
> APIs beyond what `swift/GitKit/Sources/GitKit/` and `apps/gitkanban-macos/GitKanban/` contain.

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

The **Swift side mirrors this package** and is tested (in GitKit) against shared fixtures so the
two parsers cannot drift.

### 2. `swift/GitKit` — the shared Swift engine (Exists)

The one package both native apps depend on. `apps/gitkanban-macos/project.yml` declares the
dependency (`packages: GitKit: path: ../../swift/GitKit`). Present in
`swift/GitKit/Sources/GitKit/`:

- `GitEngine` (protocol) — `clone`, `pullRebase`, `commit`, `push`, `status`,
  `fileHistory(at:file:limit:)`. **The only thing that knows git.**
- `ShellGitEngine` — macOS implementation shelling out to `git` (ported from GitFolder's
  `GitRunner`), via `GitProcessRunner`.
- `GitTypes` (`GitAuth`, `PullResult`, `RepoStatus`, `CommitInfo`), `GitEngineError`.
- `BoardStore` / `BoardMarkdown` / `BoardModel` / `BoardInheritance` — the Swift board mirror:
  read a checkout folder → workspace/projects/lanes/cards, parse frontmatter (Yams) and
  body-section fields, resolve effective config, group into columns.
- `RemoteBoardStore` + `BoardFileSource` — a transport-agnostic board loader (used by iOS over an
  API; macOS uses the filesystem via `BoardStore`).
- `CardText` — card body/frontmatter helpers.
- `KeychainService`, `GitHubOAuthService` (device-flow OAuth), `GitHubReposService` (list repos).

There is **no** `MarkdownStore`, `BoardSyncEngine`, `ConfigStore`, or `FolderAccessService` type —
earlier plans named these, but the app owns its own checkout (so it needs no security-scoped
bookmarks), reads via `BoardStore`, writes card files directly, and drives sync inline in
`AppModel`. `Libgit2Engine` is not present; iOS ships over an API transport instead (see the iOS
app).

---

## App structure

```txt
GitKanban/
  App/       GitKanbanApp (entry, ⌘-commands, task-detail WindowGroup), AppModel (@Observable
             state), RootView (restore → connect → repo picker → workspace)
  Board/     BoardView (lane carousel, backlog dock, list view, selection bar), WorkspaceView
             (projects sidebar), CardDetailView, TaskDetailWindow, FilterBar, SearchSheet,
             TaskHistorySheet, MarkdownWebView, BoardColors
  Connect/   ConnectView (device-flow), RepoPickerView
  Project/   NewProjectSheet (create + editable settings), NewTaskSheet, ProjectsEmptyState
  Resources/ markdown-renderer.html
```

Convention (root AGENTS.md): `AppModel` is the single UI-facing state object; GitKit stays
UI-agnostic so the board parsing layer can back iOS unchanged.

---

## Module boundaries and data flow

```txt
        ┌──────────────────────────────────────────────┐
        │  SwiftUI board UI  (lane carousel · card      │   Exists — render, edit,
        │  detail window · drag/reorder · filters ·     │   move, reorder, delete,
        │  search · history sheet · markdown webview)   │   filter, search, history
        └───────────────┬──────────────────────────────┘
                        │ mutates AppModel state / calls AppModel actions
                        ▼
        ┌──────────────────────────────────────────────┐
        │  AppModel (@Observable)                       │   Exists — connect, own-checkout,
        │  session, workspace, selection, filters;      │   read via BoardStore, compose
        │  create/edit/move/reorder/delete → write file │   frontmatter, commit + push
        │  → commit + push                              │
        └───────┬───────────────────────────┬──────────┘
                │ read                        │ write + git
                ▼                            ▼
   ┌─────────────────────────┐   ┌──────────────────────────────┐
   │ GitKit BoardStore /     │   │ GitKit ShellGitEngine        │   Exists
   │ BoardMarkdown / Model / │   │ clone · pullRebase · commit  │
   │ Inheritance (Yams read) │   │ · push · status · fileHistory│
   └───────────┬─────────────┘   └───────────────┬──────────────┘
               ▼                                  ▼
        ┌──────────────────────────────────────────────────────────┐
        │  App-owned checkout in Application Support (a git clone)   │
        │  <project>/<lane folder>/<card>.md + README config; git    │
        │  is the store. Lanes are folders; status must match folder │
        └──────────────────────────────────────────────────────────┘
```

**Read path:** checkout files → `BoardStore` parses cards + config (Yams) → `resolveEffectiveConfig`
→ `groupIntoColumns` → workspace/projects/columns/cards → board UI.

**Write path:** a UI action mutates a card → `AppModel` composes the card file (frontmatter edited
in place, unknown keys preserved; a lane change **moves the file** into the destination lane folder
and sets `status`) → `ShellGitEngine.commit` one logical action → `pull --rebase` then `push`.
Reorder currently writes an integer `order = index + 1` for the affected lane rather than minting a
single fractional key — see [Decisions.md](./Decisions.md) §6.

---

## Build & project generation

- **XcodeGen.** The Xcode project is generated from `project.yml` — never hand-edit the
  `.xcodeproj`. Regenerate with `cd apps/gitkanban-macos && xcodegen generate`.
- **Target:** `GitKanban`, macOS 14.0+, bundle id `app.hakobs.gitkanban`, sandboxed
  (`app-sandbox`, `network.client`, `files.user-selected.read-write`, `bookmarks.app-scope`),
  hardened runtime, category `developer-tools`. **No test target is defined yet** (tracked on the
  board).
- **Dependency:** the `GitKit` Swift package (`../../swift/GitKit`).
- **Markdown webview:** `webview/` bundles `renderer.ts` (Nizel) with esbuild; rebuild with
  `npm run gitkanban:webview:build`.
- **Core tests:** `npm run gitkanban:core:test` runs the TypeScript board-logic suite (Vitest).
- **Run:** `npm run gitkanban:run` builds and launches the app (`scripts/run.sh`).

---

## Platform trajectory

macOS shells out to `git` via `ShellGitEngine`. iOS cannot — no shell, no `git` binary — so the
iOS app talks to a hosted git provider's REST API through **git-pont** (no local clone), reusing
GitKit's `RemoteBoardStore`/`BoardFileSource` for parsing. That superseded the earlier
"`Libgit2Engine` first" plan. Details in
`/Users/silvandiepen/Projects/GitKit/GitKanban/plan/platforms-and-git.md`.
