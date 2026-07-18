# GitKanban (macOS) — Features

GitKanban is a native macOS kanban board whose **only data source is a git repository of
markdown files**. There is no product backend and no hosted database: the board *is* a folder
in a git repo the user owns, hosted wherever they host git. Every edit is a change to a file and
a commit; sync is `git pull --rebase` / `git push` against the user's own remote.

> Working tagline: *your kanban board is a git repo.*

## Status legend

| Mark | Meaning |
|---|---|
| **Shipped** | Built and working in the macOS app today. |
| **Planned** | Specced / tracked on the GitKit board; not built yet. |

The macOS app is a **full read/write kanban client**: connect a GitHub account, connect one or
more repositories (each cloned into an app-owned checkout), and manage projects, lanes, and cards
as markdown files that are committed and pushed on every change. The board *logic* (schema,
inheritance, ordering, validation) lives in the TypeScript package
[`@gitkit/gitkanban-core`](../../../packages/gitkanban-core/) and its Swift mirror in
`swift/GitKit`; the board *format* is the canonical contract in `project-assets/Tasks/README.md`.

---

## The board model

A GitKanban board is one git repo of markdown card files plus board config defined as README
frontmatter. Structure on disk is `/<project>/<lane>/<task>.md`, with `README.md` at the root and
in each project folder holding the config.

| Concept | Definition | Status |
|---|---|---|
| **Repository** | An app-owned checkout of a GitHub repo. **Several can be connected at once**; the sidebar shows a section per repo. | Shipped |
| **Project** | A top-level folder with its own `README.md` config, listed in the sidebar under its repo. | Shipped |
| **Column (lane)** | A card's `status` field mapped through config `lanes`; projected on disk as a numbered lane folder. | Shipped |
| **Card** | One markdown file = one card: YAML frontmatter (structured fields) + markdown body. | Shipped |
| **Config** | Root + per-project frontmatter (`lanes`, `users`, `priorities`, `types`, `epics`, `tags`) with inheritance. | Shipped |
| **History** | Per-card journey read from git (`git log --follow`), shown in a History sheet. | Shipped |

---

## Connect & repositories

- **GitHub sign-in** via OAuth device flow (reuses GitFolder's client). The verification code is
  shown and **copies to the clipboard on click**. Token stored in the Keychain. **Shipped.**
- **Repo picker** lists the account's repositories with a **Last Used** pin on top and a filter
  field. Picking one clones it into an app-owned checkout under Application Support. **Shipped.**
- **Multiple connected repositories.** Add more via the sidebar's **Add Repository** button (a
  sheet that excludes already-connected repos). Each repo keeps its own checkout and workspace;
  the sidebar renders one section per repo, projects nested beneath. A repo section menu offers
  **New Project**, **Refresh**, and **Disconnect**. **Shipped.**
- **Session restore.** The full connected-repo set is persisted and every repo reconnects on
  launch, reselecting the last active project. Older single-repo sessions migrate automatically.
  **Shipped.**

## The board

- **Lanes view** renders one column per lane in config order, plus a **backlog** dock (bottom or
  right) for backlog lanes and an **Uncategorised** column for cards whose `status` matches no
  lane. **Shipped.**
- **List view** — an alternate grouped-list layout, toggled from the toolbar. **Shipped.**
- **Focus-lane scaling.** As you scroll the lane carousel, lanes near the viewport centre render
  full-size and the rest scale down, with the first/last lane always full at the ends. **Shipped.**
- **Lane colours** from a named palette; used consistently across lane headers, card pills, and
  the create/settings sheets. **Shipped.**
- **Search** (⌘F) and **filters** by assignee, priority, and type, derived from the project's
  config and cards. **Shipped.**

## Cards

- **Create task** (N on a selected lane, or a lane's Add Task button): writes a new markdown card
  with frontmatter, commits, and pushes. **Shipped.**
- **Task detail window** — a real, movable, resizable macOS window (traffic lights, a `⋯` actions
  menu in the titlebar). Fields (title, lane, priority, type, assignee) are always-editable
  selects; lane and priority show their colours; type is a menu with a **Custom…** option; the
  description renders through **Nizel** in a WKWebView with an edit toggle. Actions: Show Markdown,
  Find on GitHub, History…, Export…, Delete. **Shipped.**
- **Drag to move / reorder** between lanes, applied **optimistically** (the card appears in the
  target immediately; the file move + commit run in the background and revert on error). Dragging
  toward a screen edge **auto-scrolls** the carousel; the dragged card hides in its source lane.
  **Shipped.**
- **Right-click card context menu** and **multi-select** (⌘-click) for bulk move / assign / delete
  in a single commit. **Shipped.**
- **Move = one field in one file.** Moving a card updates its `status` frontmatter (and its lane
  folder projection) and rewrites `order` only for affected cards, keeping diffs minimal. **Shipped.**

## Projects & settings

- **Create Project** — a polished sheet for name, description, lanes, priorities, and assignees.
  When several repos are connected it includes a **repository selector**. Seeds each lane folder
  and commits. **Shipped.**
- **Project Settings** — the **same sheet**, pre-filled from the project's effective config.
  Lanes can be **renamed** (folder preserved), **reordered**, **added** (folder created), or
  **removed** — removing a lane that holds tickets prompts for a target lane and **migrates** the
  cards; removed assignees are **unassigned** from their tickets. Commits + pushes on save.
  **Shipped.**

## Sync

The sync loop: connect/clone → read → an edit writes the affected card file(s) → **commit per
logical action** with a descriptive message → **`pull --rebase` then `push`**. Unborn (empty)
repos are handled by adopting the remote branch. A toolbar status reflects cloning / pulling /
committing / pushing / pushed / error. **Shipped.**

Config inheritance, fractional-rank ordering, validation, lenient (round-tripping) frontmatter,
and legacy body-section field sources are provided by the core and its Swift mirror. **Shipped.**

---

## Agents & external writers (Shipped by construction)

Because the board is just files, agents, CI, and scripts write cards and push like any other
client; GitKanban treats an inbound push as a normal pull and the new/changed cards appear. The
lenient-frontmatter rule means an external writer can add fields the app does not model and they
survive a round-trip. A dedicated MCP surface for agents is **Planned**.

## Non-goals (early)

- Realtime multiplayer / live cursors — git is not a realtime backend.
- A hosted service or accounts — the user brings their own git host.
- A full PM suite — no gantt, sprints-with-burndown, or time tracking in v1.
- Providers beyond **GitHub** in v1 (reuses GitFolder's OAuth).

See [Decisions.md](./Decisions.md) for why these choices were made and
[Architecture.md](./Architecture.md) for how the pieces fit.
