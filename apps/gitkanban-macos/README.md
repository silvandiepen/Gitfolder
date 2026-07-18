# GitKanban (macOS)

The macOS GitKanban app — a kanban board backed by a git repo of markdown files.

**Status: working read/write board.** The app builds and runs today as a full GitHub-backed
kanban client: it connects to GitHub with device-flow OAuth, clones a repo it owns into its own
container, and renders, edits, and syncs a board of markdown cards. Every mutation is committed
and pushed. Generate the Xcode project with:

```bash
cd apps/gitkanban-macos && xcodegen generate
# or, to build + run in one step:
npm run gitkanban:run
```

### What it does today

- **Connects to GitHub** via device-flow OAuth and **owns its checkout**: it clones the chosen
  repo into `~/Library/Application Support/GitKanban/checkouts/<owner>-<name>`, pulls on reopen,
  and adopts an unborn branch on an empty repo. It is *not* a folder viewer.
- **Repo picker** with a "Last Used" shortcut and filter; multiple repos can be connected at once,
  and each can be disconnected.
- **Renders projects and their boards** from the checkout — a lane carousel (with focus scaling),
  a dockable backlog, a list view, and an **Uncategorised** column for cards whose status matches
  no lane. Cards show title, a colored priority chip, type icon, and `@assignee`.
- **Creates projects** (writes a `README.md` with config frontmatter + seeded lane folders) and
  **edits Project Settings** (rename/add/remove lanes with ticket migration, priorities, members).
- **Creates, edits, moves, reorders, and deletes cards.** Editing opens a card in its own
  **detail window** with field selects (lane / assignee / priority / type) and a description
  editor/preview. Card bodies are rendered as markdown in a `WKWebView` (Nizel).
- **Drag-to-move** cards between lanes and reorder within a lane, with optimistic UI and edge
  auto-scroll. **Multi-select** (⌘-click) supports bulk move / assign / delete.
- **Filters** (assignee / priority / type), **full-text search** (⌘F), and per-card **git
  history** (`git log --follow`).
- Moving a card **moves its file into the destination lane folder** and updates its `status` so
  folder and frontmatter stay in agreement (the canonical Tasks-board contract). Every action
  commits and pushes.

## How it fits together

- **Board logic** comes from [`@gitkit/gitkanban-core`](../../packages/gitkanban-core/) (TS,
  source of truth). Swift models mirror it.
- **Git, board parsing, and services** come from the shared [`GitKit`](../../swift/GitKit/) Swift
  package — `GitEngine`/`ShellGitEngine`, `BoardStore`/`BoardMarkdown`/`BoardModel`/
  `BoardInheritance`, `RemoteBoardStore`, `KeychainService`, `GitHubOAuthService`,
  `GitHubReposService`, `CardText`.
- **Board format** is the canonical contract in
  `/Users/silvandiepen/Projects/Tasks/README.md` (folder-per-lane; card frontmatter + root/project
  config with inheritance).
- **Phase 1 scope** (macOS, shell-out git, GitHub) is in
  `/Users/silvandiepen/Projects/GitKit/GitKanban/plan/phase-1.md`.

## Structure

```txt
GitKanban/
  App/        GitKanbanApp (entry, commands, task-detail WindowGroup), AppModel (state), RootView
  Board/      BoardView, WorkspaceView, CardDetailView, TaskDetailWindow, FilterBar,
              SearchSheet, TaskHistorySheet, MarkdownWebView, BoardColors
  Connect/    ConnectView (device-flow), RepoPickerView
  Project/    NewProjectSheet, NewTaskSheet, ProjectsEmptyState
  Resources/  markdown-renderer.html
webview/      renderer.ts + esbuild build (bundles the markdown renderer)
scripts/      run.sh (npm run gitkanban:run)
```

`AppModel` is the single UI-facing `@Observable` state object. It reads boards through GitKit's
`BoardStore`, writes card files directly (frontmatter composed in `AppModel`), and drives git
through `ShellGitEngine`. There is no separate `MarkdownStore`/`BoardSyncEngine` layer — those
responsibilities live in GitKit (`BoardStore`/`BoardMarkdown`) and in `AppModel` respectively.

> **Known gaps / drift from the plan** (tracked on the GitKit board): reordering currently uses an
> integer `order` and rewrites the affected lane rather than minting a single fractional rank key;
> card writes compose frontmatter by hand rather than round-tripping through Yams; there is no
> Swift test target yet; background interval sync and a conflict-resolution UI are not built (each
> action commits+pushes immediately, last-writer-wins).
