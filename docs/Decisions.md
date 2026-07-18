# GitKit — Decisions (monorepo)

An ADR-lite log of **cross-cutting, monorepo-wide** decisions — the ones that shape the whole
repo rather than a single app. Per-app decisions live in each app's `docs/Decisions.md`.

Each entry: **Decision**, **Context**, **Rationale**, **Status** (accepted / proposed / open).
Referenced task cards use the `GITKIT-###` ids from the GitKit board
(`project-assets/Tasks/GitKit/`).

---

### 1. Reframe the repo as a GitKit monorepo housing both products

**Decision.** The repository is the **GitKit monorepo** (root package `gitkit-monorepo`), an
umbrella for git-backed apps — GitFolder and GitKanban — not a single-product GitFolder repo.

**Context.** GitFolder shipped first, and the repo was originally `gitfolder-monorepo`. GitKanban
needs the same git plumbing (engine, config, keychain, OAuth, folder access). An early draft
proposed forking GitKanban into a standalone repo. (GITKIT-001)

**Rationale.** The two apps share a large git surface that is *genuinely the same code*, so the
coupling is not premature — sharing it is the point. One repo means the apps cannot drift, while
each still ships to the App Store independently (own bundle id, target, archive script). The one
real cost is a one-time refactor to lift GitFolder's inline services into a shared package.

**Status.** Accepted (GITKIT-001, done). The GitHub repo itself is not yet renamed from `Gitfolder`
(tracked in GITKIT-007).

---

### 2. Apps depend on packages, never on each other

**Decision.** An app may depend on a shared package (`swift/GitKit` for Swift, `packages/*` for
TypeScript). An app **must never** import from another app.

**Context.** With four app targets sharing logic, cross-app imports would recreate the drift the
monorepo exists to prevent.

**Rationale.** Shared logic has exactly one home — a package. This keeps each app buildable in
isolation and makes "fix once, benefit both" real. It is the load-bearing structural rule of the
repo (stated as a hard rule in the root `AGENTS.md`).

**Status.** Accepted.

---

### 3. TypeScript packages are the source of truth for board/config contracts; Swift mirrors them

**Decision.** The board schema, config inheritance, frontmatter rules, rank-key ordering, and card
validation live in TypeScript (`packages/gitkanban-core`, and `packages/core` for GitFolder's
config contract). The Swift apps **mirror** these packages; they do not fork them.

**Context.** The same markdown/board format must be parsed identically on macOS and iOS. Two
independent Swift parsers would drift.

**Rationale.** One tested reference implementation (plus fixtures) means the macOS and iOS parsers
are checked against a single spec and can't diverge. TypeScript is chosen for the contract because
it is fast to test (Vitest) and is also what the website consumes. The canonical board format is the
shared Tasks contract (`project-assets/Tasks/README.md`).

**Status.** Accepted for `gitkanban-core`. **Caveat (open):** GitFolder's `packages/core` is
currently unconsumed by the shipping Swift app and has drifted from it (per the architecture audit);
reconciling or retiring it is tracked (GITFOLDER-004 / GITFOLDER-010). So the "TS is source of truth"
rule is *aspirational* for GitFolder and *realized* for GitKanban.

---

### 4. One shared Swift `GitKit` package, extracted from GitFolder

**Decision.** A single Swift package `swift/GitKit` owns the shared native services — `GitEngine`,
`ConfigStore`, `KeychainService`, `GitHubOAuthService`, `FolderAccessService` — extracted out of
GitFolder's inline `Services/`. Both native apps depend on it.

**Context.** GitFolder's services (`GitRunner`, `KeychainService`, `GitHubOAuthService`, etc.) were
written inline in `apps/gitfolder-macos`. GitKanban needs the same ones. (GITKIT-005)

**Rationale.** Move-and-reference, not copy-and-fork: one implementation, one set of tests, one fix
site. The extraction is done additively (shared code lands alongside GitFolder's copies, then
GitFolder is repointed and its inline copy deleted) so GitFolder is never broken and every step is
verified by the macOS xcodebuild CI.

**Status.** Accepted; **in progress** (GITKIT-005). Done so far: `KeychainService` and
`GitHubOAuthService` are shared and GitFolder now runs on them (inline copies deleted, CI green).
`ShellGitEngine` is implemented and tested in the package. Still pending: `FolderAccessService`,
`ConfigStore`, and repointing GitFolder's git path at `GitEngine`.

---

### 5. One `GitEngine` protocol, two platform implementations (shell-out macOS, libgit2 iOS)

**Decision.** Define a single `GitEngine` protocol (`clone/pullRebase/commit/push/status/fileHistory`).
macOS implements it by shelling out to the system `git` binary (`ShellGitEngine`); iOS implements it
with embedded libgit2 over HTTPS (`Libgit2Engine`). The UI only ever calls the protocol.

**Context.** iOS has **no shell, no user-invokable `git` binary, and no subprocess execution**, so
GitFolder's shell-out approach does not port. This platform delta is the defining architectural
constraint for going cross-platform. (`project-assets` `GitKit/GitKanban/plan/platforms-and-git.md`)

**Rationale.** The protocol boundary lets the same board/UI layer run unchanged on both backends and
lets the engine choice change cheaply. Ship macOS on shell-out to move fast; introduce libgit2 for
iOS. If the Mac App Store sandbox turns out to reject subprocess `git`, promote libgit2 to macOS too
and collapse to one engine — the protocol makes that switch cheap. Auth is HTTPS-with-a-Keychain-token
on both (no SSH on iOS); SSH is an advanced/optional macOS path only.

**Status.** Accepted (protocol + `ShellGitEngine` implemented). `Libgit2Engine` is **open/pending** —
a Phase-0 libgit2 clone/commit/push spike must de-risk it before iOS UI work (GITFOLDER-028).

---

### 6. XcodeGen for all Swift app projects

**Decision.** Every Swift app defines its Xcode project via a checked-in `project.yml` and generates
`.xcodeproj` with **XcodeGen**. The generated `.xcodeproj` is never hand-edited.

**Context.** Multiple Swift targets in a monorepo, edited by multiple agents/humans, need mergeable,
reviewable project definitions.

**Rationale.** `project.yml` is text — diffable, mergeable, and the single source of the target's
settings, entitlements, and package dependencies (e.g. `gitkanban-macos` declares its dependency on
`swift/GitKit` in `project.yml`). Regenerate with `npm run macos:generate` (GitFolder) or
`xcodegen generate` in the app dir.

**Status.** Accepted.

---

### 7. npm workspaces + `npm run check` as the unified gate

**Decision.** The JS/TS side is an npm workspaces monorepo (`apps/*`, `packages/*`). The single
command `npm run check` runs `typecheck` + `test` + `build` across every workspace, and is exactly
what CI runs.

**Context.** Node >= 22. TypeScript is `strict`. The website, `packages/core`, and
`packages/gitkanban-core` all live under one lockfile.

**Rationale.** One install, one gate, one thing to keep green. `check` fanning out with
`--workspaces --if-present` means adding a workspace needs no CI change.

**Status.** Accepted.

---

### 8. Four CI workflows, split by surface

**Decision.** CI is split into four GitHub Actions workflows: `check.yml` (npm workspaces on
ubuntu), `macos-native.yml` (XcodeGen generate + xcodebuild test + Release/archive of GitFolder on
macos-15), `swift-gitkit.yml` (`swift build`/`swift test` of the GitKit package, path-filtered), and
`deploy-website.yml` (build + Cloudflare Pages deploy on push to `main`).

**Context.** GitFolder's audit flagged that the repo *lacked* Swift CI; the swift package needs its
own gate independent of the app build.

**Rationale.** Each surface (npm, native app, swift package, website) has different runners and
triggers; splitting keeps them fast and independently path-filtered. The Swift package and website
workflows only fire when their paths change.

**Status.** Accepted.

---

### 9. Website deployed on Cloudflare Pages

**Decision.** The marketing/docs site (`apps/website`, Vue 3 + Vite) is built and deployed to
Cloudflare Pages via `wrangler-action` on push to `main`.

**Context.** One shared site hosts both products.

**Rationale.** Static build + edge hosting fits the no-server ethos; the workflow is a copy-forward
of GitFolder's existing Cloudflare setup. (Deploy project name is currently `gitfolder`.)

**Status.** Accepted.

---

### 10. Product plans live in `project-assets`; the code repo mirrors GitFolder's plans

**Decision.** Product specs, plans, and the task board live in the separate `project-assets` repo
(`GitKit/Gitfolder/`, `GitKit/GitKanban/plan/`, `Tasks/GitKit/`). The code repo's `docs/` mirrors the
GitFolder product plans; GitKanban's plan is *not* duplicated into the code repo.

**Context.** Plans, audits, and the kanban board are living documents maintained outside the build.

**Rationale.** Keeps the code repo focused on code and the (mirrored) GitFolder docs, while the board
contract requires every board mutation be committed to `project-assets`. This is why these monorepo
docs *reference* the existing `docs/*.md` plans rather than restating them.

**Status.** Accepted.

---

### 11. Naming and scope cleanup (deferred, tracked)

**Decision.** Renamed `apps/native-macos` → `apps/gitfolder-macos` (GITKIT-007, done), and unify TS
package scopes under `@gitkit/*` (GITKIT-008, still open) — `packages/core` is still `@gitfolder/core`
while `packages/gitkanban-core` is already `@gitkit/gitkanban-core`.

**Context.** Both names predate the GitKit reframe. With two products, `native-macos` named a
platform not a product, and the mixed `@gitfolder` / `@gitkit` scopes are inconsistent.

**Rationale.** Consistency and disambiguation; low-risk internal-only renames. Deferred (P3) because
they are cosmetic and touch CI paths and scripts, so they are batched rather than done piecemeal.

**Status.** Proposed / open (both tracked, not started).
