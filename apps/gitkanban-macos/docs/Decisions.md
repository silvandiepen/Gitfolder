# GitKanban (macOS) — Decisions

An ADR-lite log of the load-bearing decisions behind GitKanban. Each entry records the
**Decision**, its **Context**, the **Rationale**, and a **Status** (accepted / proposed / open).
These are drawn from the GitKanban plan (`project-assets/GitKit/GitKanban/plan/`), the
`@gitkit/gitkanban-core` README, and the canonical board contract
(`project-assets/Tasks/README.md`). Nothing here is invented; open questions are marked as such.

---

### 1. TypeScript is the source of truth; Swift mirrors it

**Decision.** The board schema and logic live in `packages/gitkanban-core` (TypeScript, built and
tested). The Swift apps **mirror** this package field-for-field; they do not fork or re-invent the
contract. To change the contract, change it in TypeScript first, then mirror the change in Swift.

**Context.** GitKanban ships on macOS (shell git) and later iOS (libgit2). Two independently
written parsers would inevitably drift, corrupting boards differently on each platform.

**Rationale.** One reference implementation plus shared fixtures means the macOS and iOS parsers
cannot diverge. The core is pure, fully testable without an app or git, and is exactly the part
that decides whether the whole idea is sound — so it is proven first and everything mirrors it.

**Status.** Accepted.

---

### 2. One card = one file

**Decision.** Each card is a single markdown file. Editing a card never touches another card's
bytes.

**Context.** Kanban is a stream of tiny state changes across many devices and writers (human +
agents). A shared `board.json` with an ordered array would be rewritten by every action.

**Rationale.** File-per-card isolates edits: two people working different cards merge cleanly with
zero conflict, always. The pathological "everyone rewrites the same file" conflict is designed out.

**Status.** Accepted.

---

### 3. A column is a field, not a folder (folder-per-lane is the on-disk projection)

**Decision.** At the data layer a card's column is its `status` field, mapped to a lane through the
config. Moving a card edits one line (`status: todo` → `status: done`); it does **not** move the
file. On disk the canonical contract *also* projects each lane to a folder (`1. To do/`, …), and
folder and `status` **must agree** — the folder is the projection, `status` is the truth.

**Context.** A folder-per-column layout (drag = `git mv` between `todo/` and `done/`) was
considered and rejected: history breaks (a card's journey is spread across path moves,
`git log --follow` is flakier), a move/move on the same card becomes an ugly rename/rename
conflict, and folders still don't give intra-column order. The live `Tasks/` board, however, keeps
lane folders for human browsability and requires them to match each card's `status`.

**Rationale.** Status-as-a-field keeps every move a single-line diff in a single stable file —
exactly what git merges well — while the folder projection keeps the repo readable to humans and
tools. Lanes carry their `folder` so both views stay in agreement.

**Status.** Accepted.

---

### 4. Additive, lenient frontmatter — unknown keys are preserved

**Decision.** Parse/serialize round-trips **every** frontmatter (and config) key verbatim,
including keys the app does not model. A read-then-write of an unchanged card produces a zero diff.

**Context.** Boards are written by external tools — sills audits, CI, scripts, agents — that add
fields GitKanban has never heard of. The canonical card carries a large lifecycle vocabulary
(`picked_up_by`, `reviewer`, `testing_owner`, …) beyond the fields the board UI reads.

**Rationale.** Preserving unknown keys means the app is one writer among many without being the
authority on the schema. It keeps agents' diffs readable and makes the format extensible at either
config level (components, milestones, estimates …) the same additive way. Round-trip fidelity is a
hard test gate protecting agent/sills-authored fields.

**Status.** Accepted.

---

### 5. Config inheritance: lanes replace, vocabularies merge

**Decision.** Effective config = root config overlaid with project config. A non-empty project
`lanes` list **replaces** the root lanes (custom workflow); `users`/`priorities`/`types`/`epics`/
`tags` **merge** (project entries extend root; same `id` → project wins). Implemented as
`resolveEffectiveConfig(root, project)`.

**Context.** The `Tasks/` contract defines configuration as README frontmatter at a root level and
per project, and the apps consume it as data, not just docs.

**Rationale.** Lanes are structural — a project either uses the default workflow or defines its own
whole workflow, so replace is the only coherent rule (and its lane folders must match). Vocabularies
are additive dimensions where a project should extend, not discard, shared definitions.

**Status.** Accepted.

---

### 6. Fractional rank keys for intra-column ordering

**Decision.** Position within a column is a fractional / lexicographic rank key stored as `order`
(wrappers over `fractional-indexing`). Inserting between two cards mints one new key strictly
between the neighbours' keys; only the moved card is rewritten. Boards without rank keys fall back
to priority + `created_at` + `id`.

**Context.** "Between these two cards" is the classic distributed-order problem. Integer positions
force a rewrite of every card below an insert and conflict the moment two clients insert nearby.

**Rationale.** Rank keys make an insert O(1) writes and O(1) diff, so concurrent reorders in the
same column touch different files and don't conflict. Concurrent inserts in the same gap usually
mint different keys; if they ever collide, `id` is the deterministic tiebreak — cosmetic at worst,
never data loss or a conflict on someone else's card. An occasional explicit whole-column rebalance
compacts long keys, but a drag never does.

**Status.** Accepted.

---

### 7. Body-section field source for legacy boards

**Decision.** Support two field sources: `frontmatter` (native GitKanban format) and `body-section`
(read `**Label:** value` lines from a named markdown section — the legacy `audit/tasks` format).
The source is set in config and honoured by `resolveCardFields`.

**Context.** The existing audit boards store `State`/`Assignee`/`Branch·PR` in a `## Status` body
block, not frontmatter. Hundreds of such files already exist.

**Rationale.** GitKanban can open today's boards read/write without rewriting files. A one-shot
"upgrade to frontmatter" is offered but never forced.

**Status.** Accepted.

---

### 8. Phase-1 scope: macOS, one board, shell-out git, GitHub

**Decision.** Phase 1 is **macOS only**, **one board**, git via **shelling out to the system `git`
binary** (behind the `GitEngine` protocol), **GitHub only** for auth (reusing GitFolder's
OAuth/Keychain). No iOS, no multi-board, no multi-provider, no realtime.

**Context.** The premise ("is a git repo of markdown a pleasant board?") is provable on one
platform with maximum reuse of GitFolder's macOS foundation. The real engineering risks — merge
conflicts, ordering, and git-on-iOS — are staged.

**Rationale.** Prove the schema and sync model cheaply first; defer the hard iOS/libgit2 delta to
Phase 2. The `GitEngine` protocol keeps the eventual engine swap cheap.

**Status.** Accepted.

---

### 9. GitKanban lives in the GitKit monorepo, sharing one git engine

**Decision.** GitKanban is built inside the GitKit monorepo alongside GitFolder, not as a forked
standalone repo. Both apps depend on the shared `swift/GitKit` Swift package (`GitEngine`, config,
keychain, OAuth, folder access); board logic depends on `packages/gitkanban-core`. Apps never
import each other.

**Context.** An earlier draft recommended forking into a standalone repo to avoid premature
coupling. That was reversed: the git engine is genuinely the same code.

**Rationale.** Here the coupling is not premature — sharing the engine is the point. One repo means
the two apps can't drift, one fix benefits both, and each still ships to the App Store independently
(own bundle id, target, archive script). The cost is a one-time move of GitFolder's inline services
into the shared package.

**Status.** Accepted.

---

### 10. `GitEngine` protocol boundary; shell-git now, libgit2 later

**Decision.** The app calls git only through a `GitEngine` protocol
(`clone / pullRebase / commit / push / status / fileHistory`). macOS Phase 1 uses `ShellGitEngine`
(subprocess `git`); iOS Phase 2 introduces `Libgit2Engine`. If the Mac App Store sandbox rejects
subprocess git, libgit2 is promoted to macOS too and the two collapse to one engine.

**Context.** iOS has no shell and no user-invokable `git` binary — the single biggest technical
delta from GitFolder. The sandbox's tolerance of subprocess `git` on macOS is unconfirmed.

**Rationale.** The protocol boundary lets the app move fast on shell-git while keeping the
engine swap cheap and the UI unchanged across platforms.

**Status.** Accepted (protocol + `ShellGitEngine` exist); iOS engine and the sandbox confirmation
are **open** — see below.

---

### 11. YAML frontmatter via Yams (Swift), `yaml` (TS)

**Decision.** The TS core parses/serializes frontmatter with the `yaml` package; the Swift mirror
uses **Yams**. Serialization is minimal-diff (only changed cards written).

**Context.** Frontmatter round-trip fidelity across two languages is the correctness crux (Decision
4). Card bodies are rendered with a markdown renderer (SwiftUI `AttributedString`/`Text` or a lib).

**Rationale.** Established, well-maintained YAML libraries on each side, exercised against shared
fixtures, keep the two parsers aligned without hand-rolling YAML.

**Status.** Accepted (TS). Swift Yams wiring is Planned as part of the Swift mirror.

---

### Open questions

Carried from `risks-and-open-questions.md`; recorded here so a judgment call is documented, not
silent.

- **`updated` field:** store in frontmatter or derive from `git log`? (Leaning derive-from-git to
  cut churn.) **Open.**
- **Archive vs delete:** default archived cards to an `archive/` folder or `git rm`? (Leaning
  `archive/` for browsability.) **Open.**
- **Board root discovery:** convention (`cards/` + config) vs fully explicit config for opening
  arbitrary existing folders like `audit/tasks/`. (Plan: support both.) **Open.**
- **One git engine or two:** ship macOS on shell-git and add libgit2 for iOS, or invest in
  libgit2-for-both up front? (Plan: protocol now, decide at Phase 2.) **Open.**
- **Mac App Store sandbox vs subprocess git:** confirm shell-out `git` is acceptable under
  GitFolder's entitlements, else promote libgit2 to macOS (Decision 10). **Open.**
- **iOS transport:** libgit2-HTTPS primary vs GitHub HTTP API primary for first iOS release.
  **Open.**
- **Pricing / packaging:** one-time per platform vs a single universal (macOS + iOS) purchase,
  matching GitFolder's low lifetime posture. **Open.**
- **Coexistence with GitFolder:** does GitFolder keep background-syncing a GitKanban board's
  folder, or does GitKanban own its sync entirely (avoid double-committing)? **Open.**
