# GitKanban (macOS)

The macOS GitKanban app — a kanban board backed by a git repo of markdown files.

**Status: working read-only board.** The app builds and runs today: it renders a
read-only kanban board from a folder of markdown cards, loaded via the shared
[`GitKit`](../../swift/GitKit/) package. Card **editing**, **drag-to-move** between
lanes, and **git commit/sync** are deferred to later tickets. Generate the Xcode
project with:

```bash
cd apps/gitkanban-macos && xcodegen generate
```

### What it does today

- Renders one column per lane (default five: To do / In Progress / In Review /
  Testing / Done) plus an **Uncategorised** column, with cards showing title, a
  priority capsule, and `@assignee`.
- Loads a board from a folder of markdown cards via **Open Board Folder…**
  (`⌘O`) — wired to GitKit's `BoardConfig`/`Lane`/`EffectiveConfig`,
  `BoardStore`, and `BoardMarkdown`. It auto-detects the legacy `audit` markdown
  format.
- On launch shows 3 hardcoded sample cards until a folder is opened.

## How it fits together

- **Board logic** comes from [`@gitkit/gitkanban-core`](../../packages/gitkanban-core/) (TS,
  source of truth). Swift models mirror it.
- **Git + services** come from the shared [`GitKit`](../../swift/GitKit/) Swift package
  (`GitEngine`, config, keychain, OAuth, folder access).
- **Phase 1 scope** (macOS, one board, shell-out git, GitHub) is in
  `project-assets/GitKit/GitKanban/plan/phase-1.md`.

## Planned structure

```txt
GitKanban/
  App/          GitKanbanApp, AppModel
  Models/       Card, Board, Column (mirror @gitkit/gitkanban-core)
  Services/     MarkdownStore, BoardSyncEngine (on GitKit's GitEngine)
  Board/        columns, drag/drop, card editor, history view
  Views/
```

The UI mutates domain objects only; `MarkdownStore` owns the file format and `GitEngine`
owns git, so the same board UI can later run on iOS unchanged.
