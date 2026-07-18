# GitKanban (macOS) — Decisions

An ADR-lite log of the load-bearing decisions behind GitKanban. Each entry records the
**Decision**, its **Context**, the **Rationale**, and a **Status** (accepted / proposed / open /
superseded). These are drawn from the GitKanban plan
(`/Users/silvandiepen/Projects/GitKit/GitKanban/plan/`), the `@gitkit/gitkanban-core` README, the
canonical board contract (`/Users/silvandiepen/Projects/Tasks/README.md`), and the shipped app.
Where the shipped implementation diverges from the original plan, that is called out explicitly.

---

### 1. TypeScript is the source of truth; Swift mirrors it

**Decision.** The board schema and logic live in `packages/gitkanban-core` (TypeScript, built and
tested). The Swift apps **mirror** this package (via `swift/GitKit`); they do not fork or re-invent
the contract. To change the contract, change it in TypeScript first, then mirror the change in
Swift.

**Context.** GitKanban ships on macOS (shell git) and iOS (git-pont API). Two independently written
parsers would inevitably drift, corrupting boards differently on each platform.

**Rationale.** One reference implementation plus shared fixtures means the parsers cannot diverge.

**Status.** Accepted.

---

### 2. One card = one file

**Decision.** Each card is a single markdown file. Editing a card never touches another card's
bytes.

**Context.** Kanban is a stream of tiny state changes across many devices and writers (human +
agents). A shared `board.json` with an ordered array would be rewritten by every action.

**Rationale.** File-per-card isolates edits: two people working different cards merge cleanly.

**Status.** Accepted.

---

### 3. A column is a lane folder; a card's `status` must match its folder

**Decision.** A card's column is a **folder** (`1. To do/`, `2. In Progress/`, …), and the card's
`status` field must match its lane folder. **Moving a card moves its file into the destination lane
folder and updates `status`** in the same action, so folder and frontmatter always agree.

**Context.** An earlier plan draft had the column be *only* a `status` field, with the file staying
put ("moving a card does not move the file"). The live `Tasks/` contract, however, makes lane
folders the primary, human-browsable view and requires `status` to match — and the shipped app
follows that contract. So the app **does** move the file on a lane change.

**Rationale.** Folder-per-lane keeps the repo readable to humans and tools browsing the tree, and
the card's stable `id`/filename preserves `git log --follow` across the move. The `status` field
keeps the value machine-readable and lets `groupIntoColumns` place cards without walking the tree.

**Status.** Accepted (revised from the earlier "field, not folder" draft to match the canonical
contract and the shipped app).

---

### 4. Additive, lenient frontmatter — unknown keys are preserved

**Decision.** Parse/serialize should round-trip **every** frontmatter (and config) key verbatim,
including keys the app does not model. A read-then-write of an unchanged card should produce a zero
diff.

**Context.** Boards are written by external tools — sills audits, CI, scripts, agents — that add
fields GitKanban has never heard of. The canonical card carries a large lifecycle vocabulary
(`picked_up_by`, `reviewer`, `testing_owner`, …) beyond the fields the board UI reads.

**Rationale.** Preserving unknown keys means the app is one writer among many without being the
schema authority, keeping agents' diffs readable.

**Status.** Accepted in principle and honoured by the core (TS) parser. **At risk in the app:** the
macOS app currently composes frontmatter with hand-rolled string editing in `AppModel`
(`composeFrontmatter`/`setFrontmatterKey`/`composeCard`) rather than round-tripping through
`BoardMarkdown`/Yams. Routing writes through the shared layer and adding a zero-diff round-trip test
is tracked on the board.

---

### 5. Config inheritance: lanes replace, vocabularies merge

**Decision.** Effective config = root config overlaid with project config. A non-empty project
`lanes` list **replaces** the root lanes (custom workflow); `users`/`priorities`/`types`/`epics`/
`tags` **merge** (project entries extend root; same `id` → project wins). Implemented as
`resolveEffectiveConfig(root, project)`.

**Context.** The `Tasks/` contract defines configuration as README frontmatter at root and per
project, and the app consumes it as data — reading it to render and writing it via project
create/settings.

**Rationale.** Lanes are structural (replace); vocabularies are additive dimensions (merge).

**Status.** Accepted.

---

### 6. Ordering within a lane — fractional rank keys (core) vs integer `order` (app today)

**Decision (target).** Position within a lane is a fractional / lexicographic rank key stored as
`order` (wrappers over `fractional-indexing`); inserting between two cards mints one new key and
rewrites only the moved card. Boards without rank keys fall back to priority + `created_at` + `id`.

**Context.** "Between these two cards" is the classic distributed-order problem; integer positions
force a rewrite of every card below an insert and conflict when two clients insert nearby.

**Rationale.** Rank keys make an insert O(1) writes and O(1) diff. The fallback sort handles boards
(like the audit/task boards) that carry no `order`.

**Status.** Core: **Accepted and implemented** (`rank.ts`). App: **not yet adopted** — the macOS
app currently writes an **integer `order = index + 1`** and rewrites the affected lane on reorder.
This works but reintroduces the neighbour-churn the rank keys were meant to avoid. Adopting the
fractional key path in the app is tracked on the board.

---

### 7. Body-section field source for legacy boards

**Decision.** Support two field sources: `frontmatter` (native GitKanban format) and `body-section`
(read `**Label:** value` lines from a named markdown section — the legacy `audit/tasks` format).
The source is set in config and honoured by `resolveCardFields`.

**Context.** The existing audit boards store `State`/`Assignee`/`Branch·PR` in a `## Status` body
block. Hundreds of such files exist.

**Rationale.** GitKanban can open today's boards without rewriting files.

**Status.** Accepted. Core: implemented; the app auto-detects the legacy format.

---

### 8. Phase-1 scope: macOS, shell-out git, GitHub

**Decision.** Phase 1 is **macOS**, git via **shelling out to the system `git` binary** (behind the
`GitEngine` protocol), **GitHub only** for auth (device-flow OAuth + Keychain).

**Context.** The premise ("is a git repo of markdown a pleasant board?") is provable on one platform
with maximum reuse of GitFolder's macOS foundation.

**Rationale.** Prove the schema and sync model cheaply first.

**Status.** Accepted — and **exceeded** in scope: the shipped app owns its checkout, supports
**multiple connected repos and multiple projects per repo**, and ships create/edit/move/reorder/
delete, filters, search, list view, and multi-select. What is still Planned is background interval
sync, a conflict UI, and the fractional rank keys of Decision 6.

---

### 9. GitKanban lives in the GitKit monorepo, sharing one git/board package

**Decision.** GitKanban is built inside the GitKit monorepo alongside GitFolder, not as a forked
repo. Both apps depend on the shared `swift/GitKit` Swift package (git engine, board parsing,
keychain, OAuth, repos service); board logic depends on `packages/gitkanban-core`. Apps never import
each other.

**Context.** An earlier draft recommended a standalone repo; that was reversed — the git engine and
board parsing are genuinely shared code.

**Rationale.** One repo means the two apps can't drift and one fix benefits both, while each still
ships to the App Store independently.

**Status.** Accepted.

---

### 10. `GitEngine` protocol boundary; shell-git on macOS

**Decision.** The macOS app calls git only through a `GitEngine` protocol
(`clone / pullRebase / commit / push / status / fileHistory`), implemented by `ShellGitEngine`
(subprocess `git`).

**Context.** iOS has no shell — the biggest platform delta. The protocol keeps the transport
swappable.

**Rationale.** The protocol boundary lets macOS move fast on shell-git while keeping the board UI
transport-agnostic.

**Status.** Accepted (protocol + `ShellGitEngine` exist and are used by the app). NB: iOS did **not**
implement `Libgit2Engine` behind this protocol — it ships over a REST API via git-pont using
GitKit's `RemoteBoardStore`/`BoardFileSource` instead (see Decision 12 and the iOS app).

---

### 11. YAML frontmatter via Yams (Swift), `yaml` (TS)

**Decision.** The TS core parses/serializes frontmatter with the `yaml` package; the Swift board
parsing in `swift/GitKit` uses **Yams**.

**Context.** Frontmatter round-trip fidelity across two languages is the correctness crux
(Decision 4).

**Rationale.** Established YAML libraries on each side, exercised against shared fixtures, keep the
parsers aligned.

**Status.** Accepted for the **read** path (GitKit's `BoardStore`/`BoardMarkdown` use Yams). The
macOS app's **write** path currently bypasses Yams (hand-rolled frontmatter composition in
`AppModel`); moving writes onto Yams/`BoardMarkdown` is tracked on the board (see Decision 4).

---

### 12. iOS transport superseded: git-pont REST API, not libgit2

**Decision.** The iOS app talks to a hosted git provider's REST API through **git-pont** (no local
clone), reusing GitKit's `RemoteBoardStore`/`BoardFileSource` for parsing. It does **not** use an
embedded `Libgit2Engine`.

**Context.** The plan originally gated iOS on an embedded-libgit2 `GitEngine`. In practice the iOS
app shipped read/write over provider APIs (GitHub + GitLab + self-hosted) with a personal-access
token, which was simpler and already works.

**Rationale.** API-first removes the native-dependency risk and reaches a working iOS board without
building/maintaining libgit2. An embedded offline mode remains a possible later addition, not a
gate.

**Status.** Accepted for iOS. The libgit2 path is **superseded / deferred**. (This is a macOS-app
doc; details live in the iOS app's `docs/`.)

---

### Open questions

- **`updated` field:** store in frontmatter or derive from `git log`? (Leaning derive-from-git.)
  **Open.**
- **Archive vs delete:** archive to an `archive/` folder or `git rm`? **Open.**
- **Background sync + conflict UI:** interval pull/push, per-board status states, and a
  conflict-resolution/recover-from-history flow are not built. **Open (tracked on the board).**
- **Mac App Store sandbox vs subprocess git:** confirm shell-out `git` is acceptable under the
  entitlements, else consider libgit2 for macOS too. **Open.**
- **Pricing / packaging:** one-time per platform vs a universal (macOS + iOS) purchase. **Open.**
- **Coexistence with GitFolder:** does GitFolder keep background-syncing a GitKanban board's folder,
  or does GitKanban own its sync entirely (avoid double-committing)? **Open.**
