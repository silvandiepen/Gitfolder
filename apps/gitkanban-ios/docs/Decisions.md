# GitKanban iOS — Decisions

ADR-lite log for the **planned** GitKanban iOS app. Every entry here is **Proposed** or **Open** —
nothing is implemented. These record decisions carried down from the GitKanban plan
(`project-assets/GitKit/GitKanban/plan/`), not new ones invented for iOS. Where the plan leaves an
iOS specific undecided, the entry is marked **Open**.

---

### 1. Reuse the same board logic as macOS (gitkanban-core, TS is source of truth)

**Decision:** GitKanban iOS consumes the board schema and logic from
[`@gitkit/gitkanban-core`](../../../packages/gitkanban-core/) — frontmatter parse/serialize, config
inheritance, rank keys, `status → lane` mapping, validation — via a Swift mirror, exactly as macOS
does. It does **not** define its own card/board schema.

**Context:** The board contract is platform-agnostic and already built and tested in TypeScript.
Two independent parsers would drift and produce boards that render differently per platform.

**Rationale:** One source of truth (TS) with Swift mirrors keeps macOS and iOS byte-compatible on
the same repo. It is also the monorepo's hard dependency rule: apps mirror packages, never fork them.

**Status:** Proposed.

---

### 2. Reuse the same `GitEngine` protocol as macOS

**Decision:** The app calls git only through the shared `GitEngine` protocol in
[`swift/GitKit`](../../../swift/GitKit/) (`clone / pullRebase / commit / push / status /
fileHistory`) — the same protocol macOS's `ShellGitEngine` conforms to. iOS supplies a different
implementation behind that boundary, not a different abstraction.

**Context:** The board UI and sync engine must not know which platform's git mechanism is underneath.

**Rationale:** A single protocol boundary lets one board UI run on macOS-shell-git and
iOS-libgit2 unchanged, and lets the transport decision (#3, #4) change without touching the app.

**Status:** Proposed. (Protocol exists; `ShellGitEngine` done. The iOS conformer is unbuilt — see #3.)

---

### 3. iOS git transport is embedded libgit2 (`Libgit2Engine`), shared with GitFolder iOS

**Decision:** iOS uses an embedded-libgit2 implementation of `GitEngine` (`Libgit2Engine`) as the
primary transport, since iOS has **no shell and no `git` binary** and the macOS subprocess engine
cannot port. This engine is shared with GitFolder iOS — both apps face the identical transport
problem and answer it once, in `swift/GitKit`.

**Context:** The three viable iOS options are embedded libgit2 (real on-device git), the GitHub HTTP
API (no local clone, provider-specific), or a companion sync relay (rejected — reintroduces a
server). libgit2 preserves the "it's a real git repo" and offline-first promises.

**Rationale:** Embedded libgit2 keeps the full local-clone / offline / any-host story on iOS. The
GitFolder iOS `spikes/libgit2-ios/` spike (`GITKIT-128`) proves authenticated clone/commit/
pull-rebase/push over HTTPS on-device before either app builds UI on top; the result feeds the one
shared `Libgit2Engine`. Do not build a second git engine for GitKanban.

**Status:** Proposed. The spike is scaffolded but **not yet compiled or run**; `Libgit2Engine` is
unbuilt. The **GitHub HTTP API fallback** (a read-mostly "lite" mode if libgit2 slips) is Open.

---

### 4. HTTPS + Keychain OAuth token for auth (no SSH on iOS in v1)

**Decision:** iOS authenticates git over HTTPS using a GitHub OAuth token stored in the iOS
Keychain. SSH is not targeted for v1.

**Context:** iOS has no SSH agent and no `~/.ssh`. The GitHub device-flow OAuth service already
exists in `swift/GitKit` and works on both platforms.

**Rationale:** HTTPS-over-libgit2 with a Keychain token is the natural iOS transport and matches the
fallback API path. SSH-on-iOS (libssh2) is possible but not worth the cost in v1.

**Status:** Proposed.

---

### 5. Sequence GitKanban iOS as Phase 2 (after macOS proves the board, after the transport spike)

**Decision:** GitKanban iOS is Phase 2 — it starts only after GitKanban macOS (Phase 1) proves the
markdown schema and conflict-resilient writes, and after the libgit2 transport spike de-risks
on-device git. Within Phase 2, the engine is proven before any iOS UI is built.

**Context:** The two make-or-break risks (markdown/sync fidelity, and git-on-iOS) are cheaper to
prove separately and earlier than to discover mid-UI. macOS already has a git binary; iOS does not.

**Rationale:** Prove the risky, cheap-to-test things first, then build UI on a trusted foundation.
It also lets Phase 1 reuse GitFolder's macOS scaffolding wholesale for speed.

**Status:** Proposed.

---

### 6. One shared board UI layer targeted at both platforms

**Decision:** The board UI (columns, drag/drop, reorder, card editor, history view) is written once
as a platform-agnostic SwiftUI layer intended to run on **both** macOS and iOS. It mutates domain
objects only; `MarkdownStore` owns the file format and `GitEngine` owns git.

**Context:** The clean separation between UI, `MarkdownStore`, and `GitEngine` is specifically what
allows the same board UI to run over shell-git on macOS and libgit2 on iOS unchanged.

**Rationale:** Avoids a second board UI. iOS contributes touch-native navigation and drag-and-drop
chrome around the shared board, not a reimplementation of it.

**Status:** Proposed. How much SwiftUI is literally shared vs. platform-conditional is **Open** —
it depends on what the macOS build factors out.

---

## Open questions specific to / inherited by iOS

- **Primary iOS transport for the first release:** libgit2-HTTPS vs GitHub API as primary. (Open.)
- **GitHub API fallback scope:** is a read-mostly "lite" mode shipped, and when. (Open.)
- **Shared-UI factoring:** how much of the macOS board UI is reused verbatim vs iOS-specific. (Open.)
- **Universal purchase packaging** (macOS + iOS) and pricing. (Deferred in the plan.)
- **Archive strategy** (`archive/` folder vs `git rm`) and **`updated`** (stored vs derived from
  git) — board-wide open questions that iOS inherits, not iOS decisions. (Open.)
