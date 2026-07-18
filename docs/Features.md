# GitKit — Features (monorepo overview)

This is the **monorepo-level** capability map for GitKit. It describes what GitKit is,
the products it houses, and the shared engine underneath them. Per-app detail lives in
each app's own `docs/Features.md` (linked below); GitFolder's full product plans live in
this repo's `docs/*.md` (product-spec, data-model, sync-model, etc.).

## What GitKit is

GitKit is **a monorepo for git-backed apps** — apps that make a git repository a quiet,
first-class backend for everyday work, rather than a tool you consciously operate. Two
products share one git engine, so the plumbing lives once in this repo and both depend on it.

The common thesis across every app:

- **Local-first.** The working data is a real local git clone. The UI reads and writes
  ordinary files; sync is a `pull`/`commit`/`push`, not a live dependency on a service.
- **Own-your-data.** The source of truth is plain files (folders, or markdown cards) in a
  repository the user owns and hosts wherever they host git. No proprietary store, no export
  step — the data is already portable.
- **No-server.** There is no GitKit backend. The apps talk directly to the user's git host
  (GitHub today) over the user's own credentials. Nothing is relayed through infrastructure
  we run. History, offline access, and portability come from git itself.

Concretely, "no-server" means: auth is a GitHub OAuth token in the OS Keychain; every change
is a commit; the only network calls are git transport and the GitHub API, made as the user.

## The products

| Product | What it is | Data shape |
|---|---|---|
| **GitFolder** | A macOS menu-bar app that auto-versions selected folders to GitHub — quiet snapshot commits on an interval when files change. Background sync utility. | Arbitrary folders → git history |
| **GitKanban** | A native kanban board backed by a git repo of markdown files — every card is a file, every card move is a commit. Foreground editor. | Markdown cards + board config → git history |

The two are complementary, not overlapping: GitFolder syncs any folder in the background;
GitKanban is a foreground editor for a *specific* folder shape (a board of markdown cards).
The board format is the shared Tasks contract (`project-assets/Tasks/README.md`): root/project
configuration with inheritance, and markdown cards with YAML frontmatter.

## Apps × platform × status

| App | Location | Platform / stack | Status |
|---|---|---|---|
| GitFolder (macOS) | `apps/gitfolder-macos/` | SwiftUI + AppKit menu-bar app, XcodeGen | **Shipping** (App Store) |
| GitFolder (iOS) | `apps/gitfolder-ios/` | SwiftUI, embedded libgit2 (planned) | Planned — docs/spec only; libgit2 spike outstanding |
| GitKanban (macOS) | `apps/gitkanban-macos/` | SwiftUI board app, XcodeGen | In development — read-only board UI (loads markdown boards via GitKit; editing/drag/git-sync deferred) |
| GitKanban (iOS) | `apps/gitkanban-ios/` | SwiftUI, libgit2 (planned) | Planned — Phase 2, not scaffolded |
| Website | `apps/website/` | Vue 3 + Vite, deployed on Cloudflare Pages | Shipping |

> Status is deliberately honest. Only GitFolder macOS ships today. GitKanban macOS is in
> development — it builds and renders a read-only board loaded via GitKit, with editing,
> drag-to-move, and git-sync still deferred. Both iOS apps are plan-only. The shared Swift
> package extraction (see below) is **in progress**, not complete.

## The shared engine

Both native apps depend on one Swift package, **`swift/GitKit`**, so they cannot drift:

- **`GitEngine`** — the single protocol that knows git (`clone / pullRebase / commit / push /
  status / fileHistory`). The apps call only this, so the same UI runs over different git
  backends. Two implementations:
  - `ShellGitEngine` — macOS, shells out to the `git` binary (ported from GitFolder's
    `GitRunner`). **Implemented, tested.**
  - `Libgit2Engine` — iOS, embedded libgit2 over HTTPS (iOS has no shell / no subprocess).
    **Pending** — the highest-risk unknown for iOS.
- **`KeychainService`** — generic Keychain item store. Implemented.
- **`GitHubOAuthService`** — GitHub device-flow OAuth, Foundation-only (macOS + iOS). Implemented.
- **Pending extraction** from `apps/gitfolder-macos`: `FolderAccessService` (security-scoped
  bookmarks), `ConfigStore` (per-app model), `MarkdownStore` (files ⇄ cards). These still live
  in GitFolder and are being moved out as each move can be Xcode-verified.

The board **schema and logic** are not in Swift — they live in TypeScript (`packages/gitkanban-core`)
as the source of truth, and Swift mirrors them. See `docs/Architecture.md`.

## Per-app feature docs

For product-level capabilities, see each app's own docs:

- GitFolder (macOS): `apps/gitfolder-macos/docs/Features.md` + this repo's `docs/product-spec.md`,
  `docs/data-model.md`, `docs/sync-model.md`, `docs/github-access.md`, `docs/macos-permissions.md`.
- GitFolder (iOS): `apps/gitfolder-ios/docs/Features.md`.
- GitKanban (macOS): `apps/gitkanban-macos/README.md`; board contract in
  `packages/gitkanban-core/README.md`; full plan in `project-assets` `GitKit/GitKanban/plan/`.
- Website: `apps/website/`.
