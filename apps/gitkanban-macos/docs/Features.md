# GitKanban (macOS) — Features

GitKanban is a native macOS kanban board whose **only data source is a git repository of
markdown files**. There is no product backend and no hosted database: the board *is* a folder
in a git repo the user owns, hosted wherever they host git. Every edit is a change to a file and
a commit; sync is `git pull` / `git push` against the user's own remote.

> Working tagline: *your kanban board is a git repo.*

## Status legend

| Mark | Meaning |
|---|---|
| **Exists** | Implemented and running in the app today. |
| **Planned** | Specced in the plan / tracked on the GitKit board; not built yet. |

The macOS **app builds and runs a working read/write board**. It connects to GitHub with
device-flow OAuth, clones the chosen repo into an app-owned checkout, and renders, creates, edits,
moves, reorders, deletes, filters, searches, and syncs cards — committing and pushing every
mutation. The board *logic* it uses (schema, inheritance, ordering, validation) lives in the
TypeScript package [`@gitkit/gitkanban-core`](../../../packages/gitkanban-core/) and is mirrored in
`swift/GitKit`; the board *format* is the canonical contract in
`/Users/silvandiepen/Projects/Tasks/README.md`. What remains **Planned** is background interval
sync, a conflict-resolution UI, and fractional rank keys in the app; see
[Architecture.md](./Architecture.md) for what is on disk versus tracked.

---

## The board model

A GitKanban board is one git repo (or a folder inside one) of markdown card files, laid out as
**one folder per lane**, plus a board config defined as README frontmatter. The core concepts:

| Concept | Definition | Status |
|---|---|---|
| **Board / project** | A git repo the app clones; each project is a folder of lane folders + a README config. Multiple repos and projects are supported. | Core: Exists · App: Exists (connect, clone, multi-repo, multi-project) |
| **Column (lane)** | A **folder** (`1. To do/`, …) whose cards carry a matching `status`. Folder and `status` must agree. | Core: Exists · App: Exists (render + move) |
| **Card** | **One markdown file** = one card: YAML frontmatter (structured fields) + markdown body (human prose, rendered as markdown). | Core: Exists · App: Exists (render + edit) |
| **Config** | Root + per-project frontmatter (`lanes`, `users`, `priorities`, `types`, `epics`, `tags`) with inheritance. | Core: Exists · App: Exists (read + write via create/settings) |
| **History** | Per-card journey read from git (`git log --follow`). | Engine: Exists · App view: Exists (history sheet) |

### Connect and own a repo
The app connects to GitHub with device-flow OAuth and **clones the chosen repo into its own
container** (`~/Library/Application Support/GitKanban/checkouts/<owner>-<name>`). It pulls on
reopen and adopts an unborn branch on an empty repo. It is not a folder viewer; it owns and syncs
its checkout. Multiple repos can be connected and disconnected, with a "Last Used" shortcut in the
repo picker. **Exists.** (Auth is GitHub-only for now; other providers are Planned.)

### Column = a lane folder (status must match)
Following the canonical Tasks contract, each lane is a folder and every card's `status` matches its
lane folder. **Moving a card between lanes moves its file into the destination lane folder and
updates `status`** so the two stay in agreement. `groupIntoColumns` builds columns in lane order and
puts any card whose `status` matches no lane into an `uncategorised` bucket rather than dropping it.
Core: **Exists**. Rendering (lane carousel + Uncategorised): **Exists**. Drag-to-move and bulk
move: **Exists**.

### One card = one file (frontmatter cards)
A card is YAML frontmatter for machines + a markdown body for humans. The modelled fields the app
edits are `id`, `title`, `project`, `status`, `priority`, `type`, `epic`, `assignee`, `order`.
**Unknown keys are preserved verbatim** on write (see below). The full canonical card schema — the
lifecycle fields (`picked_up_by`, `reviewer`, `testing_owner`, …) and required body sections — is
in `/Users/silvandiepen/Projects/Tasks/README.md`; GitKanban renders and edits a board of exactly
that shape. Parse/field-reading: **Exists** in core. Card editor UI (own detail window, field
selects, description edit/preview, markdown-rendered body): **Exists**.

### Config inheritance (root → project)
Configuration lives as README frontmatter at two levels and resolves to an **effective config**:

- **Root** (`Tasks/README.md`) — defaults for every project.
- **Project** (`Tasks/<project>/README.md`) — per-project overrides.
- **Lanes → replace.** A non-empty project `lanes` list fully replaces the root lanes (a custom
  workflow); empty/absent inherits root lanes. Lane folders must match the effective lanes.
- **Vocabularies → merge.** `users`, `priorities`, `types`, `epics`, `tags` extend the root set;
  a project entry with the same `id` wins.

Implemented as `resolveEffectiveConfig(root, project)`. Core: **Exists**. The app also **writes**
config: creating a project seeds its README frontmatter + lane folders, and Project Settings edits
lanes (with ticket migration when a lane is renamed/removed), priorities, and members. App:
**Exists**.

### Ordering within a lane
- **Core capability:** fractional rank keys (`order`) for free-form drag-reordering — inserting
  between two cards mints one key between the neighbours', so only the moved card is rewritten.
  Wrappers over `fractional-indexing`. Core: **Exists**.
- **What the app does today:** the app stores an **integer `order` (`index + 1`)** and rewrites the
  affected lane's cards on reorder rather than minting a single fractional key. Priority +
  `created_at` + `id` is the fallback for boards without an `order`. App reorder UI: **Exists**;
  adopting the fractional key path is **Planned** (tracked on the board).

### History from git
Per-card history comes from `git log --follow` on the file — "who moved this and when" for free.
The shared engine exposes `fileHistory(at:file:limit:)`, and the app surfaces it in a **history
sheet**. Engine: **Exists**. App view: **Exists**.

### Filters, search, list view, multi-select
- **Filters** by assignee / priority / type (`FilterBar`). **Exists.**
- **Full-text search** across cards (`SearchSheet`, ⌘F). **Exists.**
- **List view** as an alternative to the lane carousel, plus a dockable backlog. **Exists.**
- **Multi-select** (⌘-click) with bulk move / assign / delete (`SelectionBar`). **Exists.**

### Validation
`validateCard` checks a card against its effective config: required `id`/`title`/`status`, a
`status` that matches a lane, and `priority`/`type`/`assignee`/`epic` that reference configured ids.
Core: **Exists**.

### Additive / lenient frontmatter
Unknown frontmatter and config keys should round-trip untouched, so agents (sills), CI, and other
tools can add fields GitKanban does not model without data loss. Core parse/serialize: **Exists**.
Caveat: the app currently composes frontmatter with hand-rolled string editing rather than routing
writes through Yams; hardening round-trip fidelity (a zero-diff read-then-write) is **Planned**
(tracked on the board).

### Legacy compatibility (body-section field source)
Boards that keep fields as `**Label:** value` lines in a markdown section (the legacy `audit/tasks`
format) are read via a `body-section` field source — no migration needed. `resolveCardFields`
honours the config's `fieldSource`. Core: **Exists**; the app auto-detects this legacy format when
loading a board.

---

## Sync

The write loop runs on every mutation: edit writes the affected card file(s) → **commit per
logical action** with a descriptive message → **`pull --rebase` then `push`** via `ShellGitEngine`.
This is **Exists** and immediate (each action syncs at once). What remains **Planned**:

- **Background interval sync** and explicit per-board status states (synced / syncing / offline /
  needs-attention / conflict).
- **Conflict surfacing UI.** Writes are currently immediate and effectively last-writer-wins; a
  conflict-detection + recover-from-history resolver is not built. The `GitEngine` primitives it
  would build on (`pullRebase`/`status`/`fileHistory`) **Exist**.

---

## Agents & external writers (Exists by construction)

Because the board is just files in a repo the app clones, agents, CI, and scripts write cards and
push like any other client; GitKanban pulls and the new/changed cards appear. The
lenient-frontmatter rule means an agent can add fields the app does not model and they survive. This
"a human curates in a native UI, a fleet of agents populates through git" loop is the primary
differentiator — and it already runs headless on the live `/Users/silvandiepen/Projects/Tasks`
board today.

---

## Non-goals (early)

- Realtime multiplayer / live cursors — git is not a realtime backend.
- A hosted service or accounts — the user brings their own git host.
- A full PM suite — no gantt, sprints-with-burndown, or time tracking in v1.
- Providers beyond **GitHub** on macOS in v1 (the iOS app adds GitLab / self-hosted via git-pont).
- Windows / Linux / web — Apple platforms first.

See [Decisions.md](./Decisions.md) for why these choices were made and
[Architecture.md](./Architecture.md) for how the pieces fit.
