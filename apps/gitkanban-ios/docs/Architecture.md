# GitKanban iOS — Architecture

The layering of GitKanban iOS **as built**. The app connects to a git host, loads a board over the
provider's REST API (no local clone), and reads/writes cards through git-pont. The two load-bearing
pieces are the **bespoke iOS SwiftUI UI** and the **API transport** (`GitPontFileSource` over
git-pont), both of which exist and run.

## Principle

GitKanban iOS is the iOS end of a shared design. The rule:

> The UI touches the board model + `AppModel` only. **`RemoteBoardStore` + `BoardFileSource` own
> the board format;** the transport (git-pont's `GitProvider`) owns talking to the host.

Because iOS has no shell and no `git` binary, it does not use `ShellGitEngine` or any on-device git
engine. It reaches the repo over HTTPS through git-pont instead.

## Layering (as built)

```txt
┌───────────────────────────────────────────────────────────┐
│  Board UI  (SwiftUI: RootView → BoardScreen; CardSheets    │  Exists — bespoke iOS UI
│  for create/edit; swipe-delete; project switcher)          │
│                    │ calls AppModel actions                 │
└────────────────────┼──────────────────────────────────────┘
                     ▼
┌───────────────────────────────────────────────────────────┐
│  AppModel (@Observable)                                     │  Exists — connect, repos,
│  connect · list repos · load board · create/edit/move/     │  board load, writes,
│  delete · restore/sign out                                 │  Keychain token
└──────────┬───────────────────────────────┬────────────────┘
           │ load/parse                     │ read/write files
           ▼                               ▼
┌────────────────────────┐     ┌───────────────────────────────┐
│  GitKit RemoteBoardStore│     │  GitPontFileSource            │  Exists
│  + BoardMarkdown/CardText│    │  (conforms to BoardFileSource)│
│  build Workspace/columns │    │  list/readText/write/delete    │
└────────────────────────┘     └───────────────┬───────────────┘
                                               │ HTTPS REST
                                               ▼
                              ┌────────────────────────────────┐
                              │  git-pont GitProvider          │  Exists
                              │  GitPontGitHub / GitPontGitLab │
                              │  listDirectory · readFile ·    │
                              │  commitFile · deleteFile ·     │
                              │  account                       │
                              └────────────────────────────────┘
```

## Exists vs planned

| Layer | State on iOS | Where it lives |
|---|---|---|
| `gitkanban-core` board schema + logic (TS) | **Exists** (built + tested) | `packages/gitkanban-core` |
| Swift board model + parsing | **Exists** | `swift/GitKit` (`RemoteBoardStore`, `BoardFileSource`, `BoardMarkdown`, `CardText`, `BoardModel`) |
| API transport (`GitPontFileSource` over git-pont) | **Exists** | `apps/gitkanban-ios` + `_libs/git-pont` |
| Connect / repo picker / board render / card CRUD | **Exists** | `apps/gitkanban-ios/GitKanban` |
| Kanban/list view toggle + backlog-last ordering | **Exists** | `BoardScreen` (`viewMode`) |
| In-column reorder (drag → rewrite `order`) | **Exists** | `AppModel.reorderCards`, `BoardScreen` `onMove` (integer `order`, not fractional keys) |
| Markdown-rendered card descriptions | **Exists** | native `MarkdownView` |
| OAuth sign-in (vs pasted PAT) | **Planned** | PAT-only today |
| Per-card history | **Planned** | (needs a provider commit-history call) |
| Offline / local clone | **Planned** | (no clone today; API-only) |
| Sync states + conflict surfacing | **Planned** | writes are blind, last-writer-wins |
| Embedded libgit2 offline engine | **Not pursued** (possible later) | — |

## Why iOS uses an API transport (not an engine)

macOS shells out to the `git` binary. **iOS has no shell, no user-invokable `git`, and no
subprocess execution**, so `ShellGitEngine` cannot run there. The plan originally called for an
embedded-libgit2 `Libgit2Engine`; in practice the app ships over the provider's REST API through
git-pont, which was simpler and already gives read/write. Because the board is loaded and written
through `BoardFileSource`, the parsing/model layer is identical to macOS regardless of transport.

## File structure

```txt
apps/gitkanban-ios/GitKanban/
  App/
    GitKanbanApp.swift     @main; restores session on launch
    AppModel.swift         @Observable: connect, repos, board load, create/edit/move/delete
  Board/
    RootView.swift         restore → connect → repo picker → board
    BoardScreen.swift      kanban lanes OR grouped list (viewMode); backlog-last; onMove reorder;
                           swipe-delete; project switcher; refresh
    CardSheets.swift       card detail (Markdown-rendered body) + edit + NewTaskSheet
    MarkdownView.swift     lightweight native Markdown renderer for card descriptions
    GitPontFileSource.swift BoardFileSource over git-pont (list/readText/write/delete)
    BoardSource.swift      seeded demo workspace (sample board)
```

## Dependency direction (monorepo rule)

- Apps depend on packages, **never on each other**. GitKanban iOS depends on `swift/GitKit` and
  git-pont, and mirrors `packages/gitkanban-core`; it does not import from `gitkanban-macos` or
  `gitfolder-*`.
- There is no shared SwiftUI board layer today — the iOS UI is written here.

## Open (plan is silent)

- Whether an offline/local mode (embedded git or a cached working copy) is ever added. (Open.)
- How conflicts should be surfaced given writes are currently blind last-writer-wins. (Open.)
- Whether per-card history is fetched from the provider's commit API. (Open.)
