# GitKanban iOS — Decisions

ADR-lite log for GitKanban iOS **as built**. Entries are **Accepted** where the app implements them,
**Open** where the plan is silent, and **Superseded** where the shipped app diverged from the
original plan (`/Users/silvandiepen/Projects/GitKit/GitKanban/plan/`).

---

### 1. Reuse the same board logic as macOS (gitkanban-core, TS is source of truth)

**Decision:** GitKanban iOS consumes the board schema and logic from
[`@gitkit/gitkanban-core`](../../../packages/gitkanban-core/) via the Swift mirror in
`swift/GitKit` (`RemoteBoardStore`, `BoardMarkdown`, `CardText`, `BoardModel`) — it does not define
its own card/board schema.

**Context:** The board contract is platform-agnostic and already built and tested in TypeScript.
Two independent parsers would drift and render boards differently per platform.

**Rationale:** One source of truth (TS) with a Swift mirror keeps macOS and iOS byte-compatible.

**Status:** Accepted.

---

### 2. Transport is a provider REST API via git-pont, not a `GitEngine`

**Decision:** The app reads and writes the board over the host's REST API through **git-pont**
(`GitPontCore` + `GitPontGitHub`/`GitPontGitLab`), reached via `GitPontFileSource`, which conforms
to GitKit's **`BoardFileSource`**. It does **not** call the `GitEngine` protocol.

**Context:** iOS has no shell and no `git` binary, so `ShellGitEngine` cannot run. The board layer
was made transport-agnostic (`RemoteBoardStore` + `BoardFileSource`) so a non-git transport can
back it.

**Rationale:** An API transport reaches a working read/write board without an on-device git engine.

**Status:** Accepted.

---

### 3. Embedded libgit2 (`Libgit2Engine`) — superseded

**Decision (original):** iOS would use an embedded-libgit2 `GitEngine` as its primary transport.
**Reality:** superseded — the app ships over the git-pont REST API instead; no `Libgit2Engine`
exists in the repo, and no libgit2 spike was needed to reach a working board.

**Context:** The plan named libgit2 the "real answer" with the provider API as a fallback. In
practice the API path was the faster route to read/write and became the actual (and only) transport.

**Rationale:** Removing the native-dependency and App-Store-review risk of embedded libgit2 got the
app to a working board sooner.

**Status:** Superseded. An embedded offline mode remains a possible later addition, not a gate.

---

### 4. Personal access token auth over HTTPS (multi-provider)

**Decision:** iOS authenticates with a **user-supplied personal access token**, validated via the
provider account call and stored in the iOS Keychain. Providers: GitHub, GitLab.com, self-hosted
GitLab.

**Context:** The original plan assumed reusing GitFolder's device-flow OAuth (`GitHubOAuthService`).
The shipped app uses a pasted PAT across multiple providers instead, which git-pont supports
uniformly.

**Rationale:** A PAT is the simplest cross-provider credential and avoids wiring device-flow OAuth
per provider for v1.

**Status:** Accepted (diverged from the OAuth plan). Device-flow OAuth remains possible later.

---

### 5. Bespoke iOS SwiftUI UI (not a shared macOS layer)

**Decision:** The iOS board UI (`RootView`, `BoardScreen`, `CardSheets`) is written in this app as
touch-native SwiftUI. It is **not** imported from GitKanban macOS.

**Context:** The plan hoped for one shared board UI layer across platforms. The macOS UI is
AppKit/desktop-shaped (windows, drag carousels); iOS uses lists, sheets, and swipe actions.

**Rationale:** A bespoke touch UI over the *shared model* is cleaner than conditionally sharing
desktop SwiftUI. The shared layer is the board model, not the views.

**Status:** Accepted (diverged from the shared-UI plan).

---

### 6. Writes are immediate and blind (last-writer-wins) — for now

**Decision:** Each create/edit/move/delete is an immediate single provider commit
(`commitFile`/`deleteFile` with blind overwrite), after which the board reloads.

**Context:** There is no local clone and no sync loop; the API commits directly to the branch.

**Rationale:** Immediate commits are the simplest correct behavior for a single-user board and match
the "every change is a commit" promise.

**Status:** Accepted for v1. **Conflict surfacing** (detecting a lost last-writer-wins race and
offering recovery from history) is **Open** and tracked on the board.

---

## Open questions

- **OAuth sign-in:** move from a pasted personal access token to provider OAuth. (Open — PAT-only
  today.)
- **Offline / local mode:** whether iOS ever gains a cached working copy or embedded git. (Open.)
- **Conflict surfacing:** how to detect and present concurrent edits given blind writes. (Open.)
- **Per-card history:** whether to fetch it from the provider's commit API. (Open.)
- **Rank keys:** in-column reorder ships today by rewriting an integer `order` (only changed cards
  commit); adopting the core's fractional rank keys is a future refinement. (Open.)
- **Archive vs delete** and **`updated` stored vs derived** — board-wide questions iOS inherits.
  (Open.)
