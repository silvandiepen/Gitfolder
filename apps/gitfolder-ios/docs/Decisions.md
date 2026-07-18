# GitFolder iOS — Decisions (ADR-lite)

The app is unbuilt; every decision here is **proposed** or **open**. Sources: the plan
(`Projects/GitKit/Gitfolder/plans/ios-app-plan.md`), the transport rationale
(`GitKanban/plan/platforms-and-git.md`), and the libgit2 spike (`spikes/libgit2-ios/`).
Nothing here is ratified by shipped code.

---

### 1. Run git in-process via embedded libgit2

**Decision:** Use **embedded libgit2** as the iOS git engine (Option A), pushing over
HTTPS with a GitHub token. Reject the GitHub-HTTPS-API-only approach (Option B) as the
primary engine.

**Context:** iOS has no `git` binary and no `Process`/subprocess API, so the macOS
`GitRunner`/`ShellGitEngine` path cannot port. The core product requirement is "load a
full folder and browse it like a filesystem" and work offline — that is a real working
tree on disk, which only a real git implementation provides. The API-only path is
online-only, rate-limited (5000 req/hr), and not a filesystem — it fails the core
requirement.

**Rationale:** libgit2 gives a true clone, offline edits, whole-repo operations, and no
per-file API limits, mapping directly onto the existing `SyncedFolder`/`SyncStatus`
model. Keep the engine behind a protocol so the API-only path could later back a
"lite/browse-only" mode or lazy File Provider materialization.

**Status:** Proposed. Gated on the Phase 0 spike (GITFOLDER-028) proving clone/commit/
pull-rebase/push on a device.

---

### 2. SwiftGit2 vs the raw libgit2 C API

**Decision:** Prefer the **SwiftGit2** high-level wrapper *if* it can do authenticated
HTTPS push and a conflict-safe rebase on iOS; otherwise implement the engine directly on
the **libgit2 C API** (a `Clibgit2` system-library or prebuilt xcframework).

**Context:** The Swift wrappers are aging; historically their weakest area is
**authenticated push**, and their rebase/merge coverage is thin. The spike's
`Libgit2Engine.swift` documents the underlying C-API call sequences precisely because
those are the stable source of truth regardless of wrapper.

**Rationale:** Adopt the wrapper only where it demonstrably works; the C-API sequences
are already sketched, so dropping down is a known fallback rather than a rewrite. This is
the single most important finding the spike must record.

**Status:** Open — decided by the Phase 0 spike result.

---

### 3. One `GitEngine` protocol shared with macOS — not a second abstraction

**Decision:** The iOS `Libgit2Engine` conforms to the **same `GitEngine` protocol** as
the macOS `ShellGitEngine` in `swift/GitKit`. Do **not** build a separate iOS git
abstraction.

**Context:** `swift/GitKit` already defines `GitEngine`
(`clone / pullRebase / commit / push / status / fileHistory`) with `ShellGitEngine`
implemented for macOS and `Libgit2Engine` pending. The app/UI layer calls only through
that protocol, which is what lets one UI run on shell-git (macOS) and libgit2 (iOS)
unchanged.

**Rationale:** A single abstraction means the app layer is platform-agnostic and there is
one contract to test against. The spike's own `GitEngine.swift` is explicitly a temporary
iOS-side copy to be deleted once it conforms to the shared package's protocol.

**Status:** Proposed (protocol exists; iOS conformance pending).

---

### 4. Extract the shared `GitFolderKit` package before UI work

**Decision:** Extract a platform-agnostic **`GitFolderKit`** Swift package
(`SyncedFolder`, `GitFolderConfig`, `AppSettings`, `SyncStatus`, `UserFacingError`,
config (de)serialization, repo-URL normalization, validation) that both macOS and iOS
depend on, and do it **before** building iOS UI.

**Context:** The audit found the macOS Swift models and the TypeScript `packages/core`
are hand-maintained copies that have already diverged (TS claims SSH-only auth; the app
ships token auth). A third hand-copy for iOS would repeat the divergence on a new
platform.

**Rationale:** Shared source of truth removes divergence risk between the two apps. The
git-execution layer stays platform-specific behind the shared `GitEngine`; only the
domain/config/validation is shared.

**Status:** Proposed (GITFOLDER-029).

---

### 5. Conflict-safe pull-rebase — always abort to a clean tree

**Decision:** On pull-rebase, integrate remote changes; on conflict, **abort the rebase
back to a clean working tree** and surface `GitEngineError.conflict`. Never leave the tree
mid-rebase and never commit conflict markers. Block push until resolved. No in-app
resolution UI in v1.

**Context:** This is the iOS mirror of audit finding EXP-0002 / card GITKIT-013. Merge
conflicts are a v1 non-goal (detect + surface + defer, matching macOS posture).

**Rationale:** A half-rebased tree or committed conflict markers silently corrupt the
user's folder — unacceptable for a "your files stay yours" product. Aborting to clean is
the safe default until a resolution UI exists.

**Status:** Proposed. Conflict-safe rebase is also a spike acceptance criterion; if
SwiftGit2 can't guarantee it, that forces the C-API path (see Decision 2).

---

### 6. Pre-push safety scan — fix the gap, don't inherit it

**Decision:** Before the first commit/push, **scan** for secrets and large files (`.env`,
keys, credentials, DB files, large binaries), warn the user, and offer to add them to
`.gitignore`.

**Context:** The audit's headline trust finding is that the macOS app does `git add -A`
and pushes without scanning, despite the model defining `FolderSafetyState` /
`SensitivePattern`. On mobile, silently pushing a whole folder is at least as risky.

**Rationale:** iOS is a chance to implement the safety the macOS app skipped rather than
carry the gap forward. The engine stages unconditionally; the app layer must run the scan
before staging.

**Status:** Proposed (part of GITFOLDER-031).

---

### 7. Lezin markdown-editor handoff contract

**Decision:** Ship the built-in editor plus a **best-effort open-in-place** handoff to
Lezin (guarded by detection) in v1; make the **File Provider** the first-class in-place
round-trip path in v1.1. Treat the exact Lezin contract as a cross-project dependency.

**Context:** The requirement is to edit MD files with Lezin when installed and round-trip
the edits back — not a one-way "share a copy". The clean round-trip needs Lezin to honor
open-in-place (or a File Provider), which is not yet confirmed. Detection needs the Lezin
URL scheme in `LSApplicationQueriesSchemes`.

**Rationale:** Open-in-place edits the original file, so saves land back in the repo for
GitFolder to commit; a copy does not. If open-in-place can't be guaranteed, fall back to
the built-in editor and a clearly-labeled "Open in Lezin (copy)".

**Status:** Open — blocked on confirming Lezin's URL scheme, UTIs, and open-in-place
support (GITFOLDER-032).

---

### 8. Defer the File Provider extension to v1.1

**Decision:** Ship the in-app browser/editor in v1; deliver the git-backed
`NSFileProviderReplicatedExtension` in **v1.1**, not v1.

**Context:** A File Provider is the cleanest answer to "manage it" and "edit in Lezin in
place", but a replicated extension (enumeration, on-demand materialization, conflict
signaling, app group) is genuinely complex.

**Rationale:** Prove the libgit2 engine and the core product in v1 first; build the
extension on top of a proven engine rather than betting the v1 timeline on it.

**Status:** Proposed (GITFOLDER-035).

---

### 9. `git-pont` reusability is unconfirmed

**Decision:** Do not assume the macOS `git-pont` dependency is reusable on iOS; confirm
whether it builds for iOS and whether it wraps libgit2 or only assembles credentials for
the CLI.

**Context:** The macOS app depends on `git-pont` for the git credential context. If it is
CLI-oriented, it cannot back the iOS engine; only its credential/token-modeling pieces (if
any) would carry over.

**Rationale:** Avoid designing the iOS engine around a dependency that may not compile or
apply on iOS.

**Status:** Open.
