# GitKanban iOS — Architecture (Planned)

This describes the **intended** layering for GitKanban iOS. The app is unbuilt and is the
furthest-out target in the monorepo, so **treat every box below as Planned unless explicitly marked
Proven.** The two load-bearing pieces — the **iOS board UI** and the **iOS git engine
(`Libgit2Engine`)** — are both unbuilt.

## Principle

GitKanban iOS is not a rewrite; it is the iOS end of a layered design shared with macOS. The rule is
the same on both platforms:

> The UI touches **domain objects only**. `MarkdownStore` is the only thing that knows the file
> format. `GitEngine` is the only thing that knows git.

That separation is exactly what lets one board UI run over macOS shell-git and iOS libgit2 unchanged.
The only iOS-specific layer is the git engine implementation and the touch chrome around the shared
board.

## Layering

```txt
┌───────────────────────────────────────────────────────────┐
│  Board UI  (SwiftUI: columns, drag/drop, card editor,      │  shared with macOS,
│            history view)  + iOS touch navigation           │  iOS chrome — PLANNED
│                    │ mutates domain objects only           │
└────────────────────┼──────────────────────────────────────┘
                     ▼
┌───────────────────────────────────────────────────────────┐
│  Board domain  (Card, Board, Column, config)               │  Swift mirror of
│  — Swift mirror of @gitkit/gitkanban-core (TS = truth)     │  gitkanban-core — PLANNED
└──────────┬───────────────────────────────┬────────────────┘
           │                               │
           ▼                               ▼
┌────────────────────────┐     ┌───────────────────────────────┐
│  MarkdownStore         │     │  BoardSyncEngine              │  PLANNED (shared)
│  files ⇄ Card, via the │     │  orchestrates pull-rebase /    │
│  core schema rules     │     │  commit / push; sync states    │
└────────────────────────┘     └───────────────┬───────────────┘
                                               │ calls only the protocol
                                               ▼
                              ┌────────────────────────────────┐
                              │  GitEngine (protocol)          │  PROVEN (protocol +
                              │  clone/pullRebase/commit/      │  ShellGitEngine on macOS)
                              │  push/status/fileHistory       │
                              └───────┬────────────────┬───────┘
                                      │                │
                        ┌─────────────┘                └──────────────┐
                        ▼                                             ▼
          ┌──────────────────────────┐              ┌──────────────────────────────┐
          │  ShellGitEngine (macOS)  │              │  Libgit2Engine (iOS)         │
          │  subprocess `git`        │              │  embedded libgit2, HTTPS +   │
          │  PROVEN (macOS only)     │              │  Keychain OAuth token        │
          └──────────────────────────┘              │  PLANNED / UNBUILT           │
                                                     └──────────────────────────────┘
```

## Proven vs planned

| Layer | State on iOS | Where it lives |
|---|---|---|
| `gitkanban-core` board schema + logic (TS) | **Proven** (built + tested) | `packages/gitkanban-core` |
| `GitEngine` protocol | **Proven** (defined) | `swift/GitKit` |
| `ShellGitEngine` (subprocess git) | **Proven — macOS only; does not run on iOS** | `swift/GitKit` |
| `Libgit2Engine` (embedded libgit2) | **Planned / unbuilt** — the iOS git engine | `swift/GitKit` (shared with GitFolder iOS) |
| Swift domain mirror (Card/Board/Column) | Planned (macOS builds it first) | `apps/gitkanban-macos` → shared |
| `MarkdownStore`, `BoardSyncEngine` | Planned (macOS builds them first) | shared |
| Board UI (columns/drag/editor/history) | Planned — produced by macOS, run on iOS | shared |
| iOS touch navigation + drag-and-drop chrome | Planned — the genuinely iOS-specific work | `apps/gitkanban-ios` |

## Why iOS needs a different engine at all

macOS shells out to the `git` binary. **iOS has no shell, no user-invokable `git`, and no subprocess
execution**, so `ShellGitEngine` cannot run there. iOS therefore needs `Libgit2Engine` — an
embedded-libgit2 conformer to the *same* `GitEngine` protocol — to do real on-device git (clone,
commit, pull-rebase, push over HTTPS with a Keychain OAuth token). Because the app only ever calls
the protocol, swapping `ShellGitEngine` for `Libgit2Engine` is invisible above the git boundary.

## Dependency direction (monorepo rule)

- Apps depend on packages, **never on each other**. GitKanban iOS depends on `swift/GitKit` (Swift)
  and mirrors `packages/gitkanban-core` (TS = source of truth); it does not import from
  `gitkanban-macos` or `gitfolder-*`.
- The libgit2 transport is shared with GitFolder iOS and lives once in `swift/GitKit` — there is **no
  second git engine** for GitKanban.

## Open (plan is silent)

- How much of the SwiftUI board layer is shared verbatim vs. `#if os(iOS)` conditional. (Open.)
- Whether a GitHub HTTP API engine ships as a second `GitEngine` conformer for a lite mode. (Open.)
- Whether macOS also adopts `Libgit2Engine` (collapsing to one engine) — decided at Phase 2. (Open.)
