# GitKanban (macOS)

The macOS GitKanban app — a kanban board backed by a git repo of markdown files.

**Status: scaffold.** This directory holds the XcodeGen project definition; the app
sources land here as Phase 1 is built. Generate the Xcode project with:

```bash
cd apps/gitkanban-macos && xcodegen generate
```

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
