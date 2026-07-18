# GitFolder (macOS) — Decisions

An ADR-lite log of significant product, design, and technical decisions for the
GitFolder macOS app. Entries are mined from the product plans (`docs/`), the deep
Sills audit (`GitKit/Gitfolder/audit/`), and the `GITFOLDER-0xx` task cards. Where
a decision is not yet made, it is recorded as **Open**.

Status legend: **accepted** (in the shipping code) · **proposed** (planned,
tracked) · **open** (undecided, needs a call).

---

### 1. Native SwiftUI/AppKit menu-bar app, not Electron

**Decision:** Build GitFolder as a native macOS menu-bar app (SwiftUI +
`MenuBarExtra`, AppKit for panels), `LSUIElement` with no main window.

**Context:** The product needs real macOS folder permissions, security-scoped
bookmarks, status-bar behavior, and App Store signing (`docs/implementation-plan.md`
Task 3; `docs/macos-permissions.md`).

**Rationale:** Electron cannot cleanly deliver sandboxed security-scoped folder
access or menu-bar-first behavior; a native app is the honest fit for a €5
developer utility.

**Status:** accepted.

---

### 2. Local-first, no backend, no account

**Decision:** All state is local — `config.json` in Application Support plus the
GitHub token in the Keychain. No GitFolder account, server, license server, or
analytics. GitHub is only the user-selected Git remote.

**Context:** v1 is a one-time €5 Mac App Store purchase; Apple handles purchase
and entitlement (`docs/app-store.md`, `docs/data-model.md`).

**Rationale:** A one-time paid utility should not carry recurring infrastructure
cost or a privacy-eroding data pipeline. Keeps the app auditable and cheap.

**Status:** accepted. (Verified by audit: no telemetry, token never in config.)

---

### 3. GitHub token / OAuth device flow as the default auth path — reversing the SSH-first plan

**Decision:** The shipping app defaults every folder to **GitHub token auth**,
obtained via an OAuth **device flow** ("Connect GitHub") or a pasted fine-grained
PAT. Repository URLs are HTTPS.

**Context:** The original plan and `docs/` (`github-access.md`, `phase-1.md`)
declared OAuth *out of scope* and specified an **SSH-first** Phase 1 using the
user's existing SSH setup. The code evolved the other way. The app-level
`README.md` reflects the token model; the top-level `docs/` and marketing site do
**not** — the audit's single largest theme is this specification-vs-reality drift
(ARC-0003, CNT-0001/0002, EXP-0003).

**Rationale:** A device-flow token is far lower friction for a paid consumer app
than requiring a working SSH key; it also enables the in-app "test access" and
"load branches" features. SSH remains valuable only for advanced users.

**Status:** accepted (in code). The doc/marketing reconciliation is **proposed**
(GITFOLDER-004); the docs still teach a non-shipping SSH flow.

---

### 4. SSH auth: engine-supported but UI-unreachable — fate undecided

**Decision (pending):** SSH auth is implemented in `GitSyncEngine` and persisted
in `AppSettings` (key path + security-scoped bookmark), but **no UI reaches it**.
`AppModel.chooseSSHPrivateKey`/`clearSSHPrivateKey` are dead, and
`tokenAuthDraft()` silently rewrites a folder's stored `authMode` to token on save.

**Context:** `README.md` still claims "Advanced SSH support" (ARC-0005).

**Rationale for deciding:** Either ship SSH as a real Advanced feature (add the
key-picker UI, stop rewriting `authMode`) or delete the dead paths and the README
claim — carrying unreachable auth code is latent complexity and a false claim.

**Status:** open (GITFOLDER-019).

---

### 5. System `git` subprocess vs. App Sandbox — the central distribution question

**Decision (pending):** The whole sync path shells out to the **system `git`**
(and `ssh` for SSH) from hardcoded, out-of-container paths (`GitRunner`), while the
app declares App Sandbox + hardened runtime and targets "Mac App Store only".

**Context:** A clean MAS customer has no developer `git`, and executing
out-of-container binaries conflicts with the sandbox — so the v1.0.0 candidate is
**not submittable to the MAS as configured** (the audit's top release blocker,
READY-0001/0002). There is also no signing/notarization/upload pipeline (CI uses
`CODE_SIGNING_ALLOWED=NO`).

**Rationale for deciding:** Two viable paths — (a) Developer-ID + notarization
(keeps the external-git model, requires the user to have Git, drops the MAS-only
goal), or (b) re-architect Git into an in-process/library engine so it runs inside
the sandbox for the MAS. Must be chosen before any submission.

**Status:** open (GITFOLDER-001, -026).

---

### 6. Snapshot model: whole-folder `git add -A`, commit, pull --rebase, push

**Decision:** On each sync with changes, stage everything (`git add -A`), make one
snapshot commit (`GitFolder snapshot <ISO-8601>`), `pull --rebase`, then non-force
`push`. Never force-push; never auto-resolve conflicts; no empty commits.

**Context:** `docs/sync-model.md` safety rules; `GitSyncEngine.syncSynchronously`.

**Rationale:** Snapshot-per-interval is the simplest model that gives folders
history without manual Git. Rebase-before-push and no-force-push keep it "safe
before clever".

**Status:** accepted — with two known gaps: no pre-push safety scan (Decision 7)
and no conflict handling (Decision 8).

---

### 7. Pre-push safety scan / `.gitignore` / preview — specified but unbuilt

**Decision (pending):** The whole folder is committed and pushed with **no** secret
scan, no `.gitignore` management, no size guard, and no content preview — and the
first-run flow ("Test, Add and Sync") pushes immediately.

**Context:** The safety subsystem (`FolderSafetyState`, `SensitivePattern`, a
`scan_safety` step, minimum patterns `.env`/`*.pem`/`*.key`/`id_rsa`/`*.sqlite`…)
is defined in `packages/core` and `docs/` (implementation-plan Task 9) but has no
Swift implementation. The audit rates this a **critical, release-blocking** trust
failure (TRUST-0001/0002, EXP-0001): a user can silently publish secrets to a
public repo, irreversibly into history.

**Rationale for deciding:** For a tool whose entire job is uploading arbitrary
folders, a pre-push guardrail was scoped as a Phase 1 requirement and should ship
before wide release.

**Status:** open / proposed (GITFOLDER-002).

---

### 8. Conflict handling: modeled states never produced

**Decision (pending):** `SyncStatus.conflict` and `needs_attention` are defined,
rendered, and wired into notification prefs, but **no code path assigns them**. A
`pull --rebase` conflict throws `pullRebaseFailed`, surfaces as generic `error`,
and leaves the repo mid-rebase with no `git rebase --abort`.

**Context:** `docs/sync-model.md` and `docs/edge-cases.md` specify pausing a
conflicted folder into a `conflict` state (EXP-0002, TEST-0002).

**Rationale for deciding:** Without abort/recovery, a conflict poisons every
subsequent sync of that folder and can commit conflict markers.

**Status:** open (GITFOLDER-003).

---

### 9. Config persistence: atomic JSON with schemaVersion and backup-on-invalid; migration deferred

**Decision:** `ConfigStore` writes `config.json` atomically, guards
`schemaVersion == 1`, and backs up an unreadable/incompatible file before failing.
No migration engine exists.

**Context:** `docs/data-model.md` specifies explicit ordered migrators and "never
silently delete folders". Today a differing `schemaVersion` backs up then resets
the in-memory config to `.empty`, and the next `save()` overwrites the folder list
(ARC-0006, GITFOLDER-017).

**Rationale:** Fail-safe-don't-corrupt is correct for a single-version v1.0.0, but
the reset-to-empty path is a latent data-loss bug the moment a v2 schema ships.

**Status:** accepted for v1 storage; migration **proposed** (GITFOLDER-017).

---

### 10. Shared Swift package (`swift/GitKit`) — extract app services over time

**Decision:** Cross-app Swift logic lives in `swift/GitKit`. GitFolder already
consumes GitKit's **`KeychainService`** and **`GitHubOAuthService`**. GitKit also
defines a `GitEngine` protocol with a `ShellGitEngine` (ported from GitFolder's
`GitRunner`) and a planned iOS `Libgit2Engine`.

**Context:** Root `AGENTS.md` dependency rule: apps depend on packages, never on
each other; the Swift apps mirror the shared package, they don't fork it. GitKit
`README.md` lists `FolderAccessService`, `ConfigStore`, and a `MarkdownStore` as
**pending extraction** — they still live inline in GitFolder.

**Rationale:** One git/keychain/OAuth implementation shared by GitFolder and
GitKanban (macOS + iOS) avoids a third hand-copy (GITFOLDER-029). Extraction is
staged because each move needs an Xcode build to verify GitFolder still compiles.

**Status:** accepted (direction); extraction **in progress**. Note: GitFolder's
`GitSyncEngine` still uses its **own** `GitRunner` + `git-pont`, not GitKit's
`GitEngine`, so the engine consolidation is not done.

---

### 11. GitHub credential context via `git-pont` — pinned to a mutable branch

**Decision:** Token→Git credential wiring for HTTPS goes through the external
`git-pont` SwiftPM package (`GitPontCore`/`GitPontGitCLI`), touched in exactly one
function (`GitAuthContext.githubToken`). The token is injected via environment
(`GITPONT_TOKEN`, `GIT_TERMINAL_PROMPT=0`), not argv — asserted by tests.

**Context:** `project.yml` pins `git-pont` to `branch:
codex/initial-git-pont-monorepo` with no committed `Package.resolved`
(SEC-0001, ARC-0007, READY-0005).

**Rationale:** Localizing the credential coupling to one function is healthy; the
**branch pin is not** — it makes release builds non-reproducible and lets upstream
change credential handling silently. Pin to a tag/commit before shipping.

**Status:** accepted (design); pin **must change** before release (GITFOLDER-006).

---

### 12. `packages/core` (TypeScript) as the config contract — currently a false source of truth

**Decision (pending):** `packages/core` was intended as the shared config contract
that Swift mirrors, but it is **imported by nothing**, has diverged (it rejects the
`github_token` authMode the app writes, omits Swift-only settings), and exports a
large aspirational surface (SyncRun/SyncStep/FolderSafetyState/LogEntry).

**Context:** ARC-0001/0002, API-0001. Either retire it and let `docs/data-model.md`
be the acknowledged human contract, or regenerate it from / into the Swift source
of truth with a CI parity check.

**Rationale for deciding:** A contract that contradicts the app and enforces
nothing actively misleads contributors; three hand-copies (TS, Swift-macOS,
future Swift-iOS) guarantee drift.

**Status:** open (GITFOLDER-010, -029).

---

### 13. Keychain storage class: device-bound, non-syncing

**Decision:** The GitHub token is stored with
`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (`KeychainService`).

**Context:** Security/privacy stance (`docs/app-store.md`); audit positive finding.

**Rationale:** Keeps the token off iCloud Keychain sync and inaccessible before
first unlock, matching the "your credentials stay on your device" claim.

**Status:** accepted.

---

### 14. App identity & versioning

**Decision:** Bundle id `app.hakobs.gitfolder`, category Developer Tools, min
macOS 14.0, `MARKETING_VERSION` 1.0.0 / build 1, automatic signing, team
`38MGF83L2L` (`project.yml`).

**Context:** Release-hygiene audit notes no git tag, no `CHANGELOG`, no `LICENSE`,
work on a feature branch (READY-0007).

**Rationale:** Standard menu-bar-utility packaging; release hygiene is a tracked
follow-up.

**Status:** accepted (identity); release hygiene **proposed** (GITFOLDER-026).

---

### 15. Monorepo naming: `native-macos` → `gitfolder-macos`

**Decision (accepted, done):** The app directory was renamed from
`apps/native-macos/` to `apps/gitfolder-macos/` (GITKIT-007).

**Context:** With a second product (GitKanban) under the GitKit umbrella,
`native-macos` was ambiguous — it names a platform, not a product.

**Rationale:** Consistency with `gitkanban-macos`/`gitkanban-ios`; the folder now
names the product it holds. Older branches/PRs and the top-level `docs/` plans may
still reference `native-macos`.

**Status:** open (GITKIT-007).
