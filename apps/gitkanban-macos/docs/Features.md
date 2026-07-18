# GitKanban (macOS) — Features

GitKanban is a native macOS kanban board whose **only data source is a git repository of
markdown files**. There is no product backend and no hosted database: the board *is* a folder
in a git repo the user owns, hosted wherever they host git. Every edit is a change to a file and
a commit; sync is `git pull` / `git push` against the user's own remote.

> Working tagline: *your kanban board is a git repo.*

## Status legend

| Mark | Meaning |
|---|---|
| **Exists** | Implemented and tested today (TS core, board contract, shared git engine pieces). |
| **Planned** | Specced in the plan / tracked on the GitKit board; not present in this app directory yet. |

The macOS **app itself is a scaffold** — `project.yml` + `README.md` only. The board *logic* it
will render (schema, inheritance, ordering, validation) already **exists** in the TypeScript
package [`@gitkit/gitkanban-core`](../../../packages/gitkanban-core/), and the board *format* is
the canonical contract in `project-assets/Tasks/README.md`. The Swift UI is Planned; see
[Architecture.md](./Architecture.md) for what is on disk versus tracked.

---

## The board model

A GitKanban board is one git repo (or a folder inside one) of markdown card files plus a board
config defined as README frontmatter. The core concepts:

| Concept | Definition | Status |
|---|---|---|
| **Board** | A git repo / folder of card files + config. Phase 1 ships **one** board. | Core: Exists · App: Planned |
| **Column (lane)** | Derived from a card's `status` field, mapped through the config's `lanes`. **A column is a field, not a folder** at the data layer. | Core: Exists · App: Planned |
| **Card** | **One markdown file** = one card: YAML frontmatter (structured fields) + markdown body (human prose). | Core: Exists · App: Planned |
| **Config** | Root + per-project frontmatter (`lanes`, `users`, `priorities`, `types`, `epics`, `tags`) with inheritance. | Core: Exists |
| **History** | Per-card journey read from git (`git log --follow`). | Engine: Exists · App view: Planned |

### One board = one git repo of markdown files
Point the app at a repo + folder; it clones if needed, opens a local clone, parses the config
and cards, and renders the board. Because the whole board is plain files, anything that reads a
folder — editors, scripts, CI, agents — can read and write it. **Planned** (open/clone flow is
tracked as Phase-1 work); the parsing rules it depends on **Exist** in the core.

### Column = a `status` field
Moving a card between columns changes **one field in one file** (`status: todo` → `status: done`);
it does not move the file. This keeps `git log --follow` on a card continuous and keeps diffs to
a single line. On disk the canonical contract also projects each lane to a **folder** (e.g.
`1. To do/`), and folder and `status` must agree — folder-per-lane is the on-disk *projection*,
`status` is the data-layer truth. `groupIntoColumns` builds columns in lane order and puts any
card whose `status` matches no lane into an `uncategorised` bucket rather than dropping it.
Core: **Exists**. UI rendering/drag: **Planned**.

### One card = one file (frontmatter cards)
A card is YAML frontmatter for machines + a markdown body for humans. The modelled fields the app
understands are `id`, `title`, `project`, `status`, `priority`, `type`, `epic`, `assignee`,
`order`. **Unknown keys are preserved verbatim** on round-trip (see below). The full canonical
card schema — the lifecycle fields (`picked_up_by`, `reviewer`, `testing_owner`, …) and required
body sections — is in `project-assets/Tasks/README.md`; GitKanban renders a board of exactly that
shape. Parse/serialize/field-reading: **Exists** in core. Card editor UI: **Planned**.

### Config inheritance (root → project)
Configuration lives as README frontmatter at two levels and resolves to an **effective config**:

- **Root** (`Tasks/README.md`) — defaults for every project.
- **Project** (`Tasks/<project>/README.md`) — per-project overrides.
- **Lanes → replace.** A non-empty project `lanes` list fully replaces the root lanes (a custom
  workflow); empty/absent inherits root lanes.
- **Vocabularies → merge.** `users`, `priorities`, `types`, `epics`, `tags` extend the root set;
  a project entry with the same `id` wins.

Implemented as `resolveEffectiveConfig(root, project)`. Core: **Exists**.

### Ordering within a column
Two ordering strategies, both supported by the core:

- **Fractional rank keys** (`order`) for free-form drag-reordering — inserting between two cards
  mints one new key between the neighbours' keys, so only the moved card is rewritten (no
  neighbour churn, no array-rewrite conflicts). Wrappers over `fractional-indexing`.
- **Priority + `created_at` + `id`** fallback for boards (like the audit/task boards) that carry
  no rank keys. `compareCards` uses `order` first, then priority, then `created_at`, then `id`.

Core: **Exists**. Drag-to-reorder UI (minting one key): **Planned**.

### History from git
Per-card history comes from `git log --follow` on the file — "who moved this and when" for free.
The shared engine already exposes `fileHistory(at:file:limit:)`. Engine: **Exists**. History
**view** in the app: **Planned**.

### Validation
`validateCard` checks a card against its effective config: required `id`/`title`/`status`, a
`status` that matches a lane, and `priority`/`type`/`assignee`/`epic` that reference configured
ids. A card referencing an unknown id is a surfaced config error, not silent drift. Core:
**Exists**.

### Additive / lenient frontmatter
Unknown frontmatter and config keys round-trip untouched, so agents (sills), CI, and other tools
can add fields GitKanban does not model without data loss. A read-then-write of an unchanged card
must produce a zero diff (a hard test gate). Core: **Exists**.

### Legacy compatibility (body-section field source)
Boards that keep fields as `**Label:** value` lines in a markdown section (the legacy `audit/tasks`
format) are read via a `body-section` field source — no migration needed. `resolveCardFields`
honours the config's `fieldSource`; a `body-section` source reads `status`/`assignee`/etc. from a
named section (falling back to the whole body), and `title` falls back to the H1. Core: **Exists**.

---

## Sync (Planned)

The sync loop mirrors GitFolder's: open/clone → read → edit writes the affected card file(s) →
**commit per logical action** with a descriptive message → **`pull --rebase` then `push`** on an
interval and on demand. Per-board status states: synced / syncing / offline / needs-attention /
conflict.

- **Conflicts are surfaced, never silently discarded.** The schema (one file per card,
  status-as-field, rank keys) designs most conflicts out; the ones that remain are single readable
  lines. A card that loses a last-writer-wins race stays recoverable from git history.
- **Write churn discipline:** only changed cards are written; `updated` is leaned toward
  derive-from-git; rapid edits may be debounced into one commit in a "quiet mode".
- **No realtime.** Sync latency = the pull interval, communicated as a feature (calm, not chatty).

Status: **Planned** (Phase 1). The `GitEngine` primitives it builds on (`clone/pullRebase/commit/
push/status/fileHistory`) **Exist** in `swift/GitKit`.

---

## Agents & external writers (Planned surface, Exists by construction)

Because the board is just files, agents, CI, and scripts write cards and push like any other
client; GitKanban treats an inbound push as a normal pull and the new/changed cards appear. The
lenient-frontmatter rule means an agent can add fields the app does not know and they survive. This
"a human curates in a native UI, a fleet of agents populates through git" loop is the primary
differentiator — and it already runs headless on the live `project-assets/Tasks` board today.

---

## Non-goals (early)

- Realtime multiplayer / live cursors — git is not a realtime backend.
- A hosted service or accounts — the user brings their own git host.
- A full PM suite — no gantt, sprints-with-burndown, or time tracking in v1.
- Providers beyond **GitHub** in v1 (reuses GitFolder's OAuth).
- Windows / Linux / web — Apple platforms first. iOS is Phase 2.

See [Decisions.md](./Decisions.md) for why these choices were made and
[Architecture.md](./Architecture.md) for how the pieces fit.
