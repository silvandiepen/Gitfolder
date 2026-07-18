# GitKanban (iOS)

The iOS counterpart of the GitKanban board app — the same "your kanban board is a git repo"
contract as [GitKanban macOS](../gitkanban-macos/), rendered on a touch UI.

**Status: Planned (Phase 2 — after GitKanban macOS and the iOS git engine).**
No code lives here yet; this directory is a docs/spec home only.

## What it is

A native SwiftUI kanban app whose data source is a git repository of markdown card files. It
reads the same boards macOS reads (one card = one markdown file with YAML frontmatter, column =
a card's `status` field), reusing the shared board logic and the shared git engine rather than
inventing its own.

The defining difference from macOS is transport: **iOS has no shell and no `git` binary**, so it
cannot shell out to `git` the way macOS does. GitKanban iOS depends on the shared
**`Libgit2Engine`** — an embedded-libgit2 implementation of the same `GitEngine` protocol macOS's
`ShellGitEngine` conforms to. That engine is not built yet; de-risking it is the gate for this app.

## Dependencies

| Depends on | For | Status |
|---|---|---|
| [`@gitkit/gitkanban-core`](../../packages/gitkanban-core/) | Board schema + logic (TS, source of truth; Swift mirrors) | Built + tested |
| [`swift/GitKit`](../../swift/GitKit/) — `GitEngine` protocol | The git abstraction the app calls | Protocol + `ShellGitEngine` done |
| `swift/GitKit` — `Libgit2Engine` | On-device git for iOS (no shell) | Planned / unbuilt |
| [GitKanban macOS](../gitkanban-macos/) | Proves the board + the shared UI layer first | Scaffold (Phase 1) |

The libgit2 transport question is shared with GitFolder iOS and is answered by the
`spikes/libgit2-ios/` spike (card `GITKIT-128` / `GITFOLDER-028`), which must land before this app.

## Where the plan and tasks live

- **Plan:** `project-assets/GitKit/GitKanban/plan/` — start with `platforms-and-git.md` (the
  macOS-vs-iOS git story), then `architecture.md` and `implementation-plan.md` (Phase 2).
- **Tasks:** the `GitKit` board in `project-assets/Tasks/GitKit/`, epic **`gitkanban-ios`**
  ("libgit2 engine + iOS board — Phase 2"). The epic is defined; no cards are open in it yet.
- App-specific agent rules: [`AGENTS.md`](./AGENTS.md). Detail: [`docs/`](./docs/).
