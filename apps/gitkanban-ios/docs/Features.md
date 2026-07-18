# GitKanban iOS — Features

GitKanban iOS is a working read/write kanban board that talks to a git host over its REST API
(through git-pont) — no local clone. It ships the **same board contract as macOS**, so a board
authored or edited on one platform renders on the other. Where a feature is not built yet, it is
marked **Planned**; where the plan is silent on an iOS specific, the entry says **Open**.

## Status legend

| Mark | Meaning |
|---|---|
| **Done** | Implemented and running in the app today. |
| **Planned** | Specced / tracked on the GitKit board; not built yet. |

## Guiding contract (inherited, not re-invented)

- A board is a repo of markdown card files; **a lane is a folder** and a card's `status` matches its
  lane folder (they must agree).
- One card = one markdown file (YAML frontmatter + markdown body).
- Config inheritance (`root` → `project`): lanes **replace**, vocabularies **merge**.
- Unknown frontmatter/config keys are **preserved on round-trip**.

All of the above is owned by [`@gitkit/gitkanban-core`](../../../packages/gitkanban-core/)
(TypeScript, the source of truth) and mirrored into Swift (`swift/GitKit`). iOS consumes that mirror
via `RemoteBoardStore` + `BoardFileSource` — it does not fork the schema.

## Feature set

| Feature | What it is on iOS | Status | Notes |
|---|---|---|---|
| Connect | GitHub / GitLab.com / self-hosted GitLab with a **personal access token** | Done | Validated via `provider.account`; token in Keychain, provider in UserDefaults; auto-restore |
| Repositories | List + search the account's repos; pick one | Done | Via git-pont |
| Open a board | Load workspace/projects over the API — **no clone** | Done | `GitPontFileSource` + `RemoteBoardStore` |
| Multi-project | Switch projects when a repo has several | Done | Project switcher in `BoardScreen` |
| Board rendering | **Kanban lanes or a grouped list** (toggle), backlog lanes ordered last, Uncategorised column | Done | `BoardScreen` `viewMode`; lane color/count, priority chips, id/`@assignee` |
| Create card | New `.md` with frontmatter + slug id, committed | Done | `NewTaskSheet` → `commitFile` |
| Edit card | Fields + body; moving lanes = write new path + delete old; description rendered as Markdown in the detail | Done | `CardSheets`, native `MarkdownView` |
| Move between lanes | Rewrite `status`, write new path, delete old | Done | Via edit; **no drag-and-drop** — a lane picker |
| Reorder within a lane | Drag (`onMove`) rewrites `order` frontmatter; only changed cards commit | Done | `AppModel.reorderCards`, `BoardScreen` `onMove` (integer `order`, not fractional keys) |
| Delete card | Swipe action or confirm dialog | Done | `deleteFile` |
| OAuth sign-in | Provider OAuth instead of a pasted PAT | Planned | PAT-only today; `RootView` notes per-server OAuth as future |
| Per-card history | "Who moved this and when" | Planned | Would need a provider commit-history call |
| Offline / local-first | Edits work offline, sync later | Planned | No clone today; API-only |
| Git sync / conflict | Sync states, conflict surfacing | Planned | Writes are immediate + **blind (last-writer-wins)** |

## Platform-specific notes

- **Transport:** the provider's **REST API over HTTPS via git-pont** — `listDirectory`/`readFile`
  to read, `commitFile`/`deleteFile` to write. No local clone, no `git` binary, no libgit2.
- **Auth:** a user-supplied **personal access token** (not device-flow OAuth), stored in the iOS
  Keychain. Multi-provider (GitHub, GitLab.com, self-hosted GitLab).
- **Writes:** each mutation is an immediate single commit; the board then reloads. Writes use blind
  overwrite (last-writer-wins) — there is no conflict detection yet.

## Explicit non-goals (mirror the product spec)

- No realtime multiplayer.
- No hosted service or accounts — the user brings their own git host and token.
- Not a full PM suite — no gantt, sprints/burndown, or time tracking.

## Not pursued

- **Embedded libgit2 / on-device git engine.** The plan originally gated iOS on a `Libgit2Engine`;
  the app shipped over the git-pont REST API instead. An embedded offline mode remains a possible
  later addition, not a prerequisite.
