# GitKit — Architecture (monorepo)

The shape of the GitKit monorepo: its layout, the dependency rule, the shared-engine strategy,
the TypeScript-source-of-truth ↔ Swift-mirror relationship, and the build/test/CI topology. For a
single app's internal architecture, see that app's own `docs/Architecture.md`. GitFolder's product
plans live in this repo's `docs/*.md` and are referenced, not restated, here.

## Layout

```txt
apps/
  native-macos/       GitFolder — macOS menu-bar app (SwiftUI/AppKit, XcodeGen). Shipping.
                      (rename → gitfolder-macos is tracked: GITKIT-007)
  gitfolder-ios/      GitFolder — iOS app. Planned; docs/spec only, no code.
  gitkanban-macos/    GitKanban — macOS board app (SwiftUI, XcodeGen). In development (scaffold).
  gitkanban-ios/      GitKanban — iOS app. Planned; not yet scaffolded.
  website/            Marketing/docs site (Vue 3 + Vite). Shipping.
packages/
  core/               @gitfolder/core — GitFolder's TS config contract (see caveat below).
  gitkanban-core/     @gitkit/gitkanban-core — GitKanban board schema + logic (TS, tested).
swift/
  GitKit/             Shared Swift package: GitEngine + app services. Extraction in progress.
docs/                 Global GitKit docs (this file) + GitFolder product plans.
```

Two package ecosystems live side by side: **npm workspaces** (`apps/*` + `packages/*`, one
lockfile) for TypeScript/Vue, and **Swift Package Manager / XcodeGen** for the native apps. The
Swift package `swift/GitKit` is *not* an npm workspace; the native apps consume it via SPM.

## The dependency rule (hard)

Apps depend on packages, **never on each other**. Shared logic belongs in a package —
`swift/GitKit` (Swift) or `packages/*` (TypeScript) — not a cross-app import.

```txt
        apps/native-macos ─┐            ┌─ apps/gitfolder-ios (planned)
   apps/gitkanban-macos ───┼── depend ──┤
    apps/gitkanban-ios ────┘   on       └─  (never on each other)
                                │
                                ▼
                        swift/GitKit  (Swift: GitEngine + services)
                        packages/*    (TS:  board/config contracts)

        apps/website ── depends on ── packages/* (TS)
```

## Shared-engine strategy

The native apps share one Swift package so they cannot drift. The package is organised around two
boundaries — the thing that knows **git**, and the thing that knows the **file format** — and the
UI touches neither directly.

```txt
UI (SwiftUI: board / cards / folders / history)
        │  mutates domain objects only
        ▼
Domain (Card, Board, Column  |  SyncedFolder, Config)   ← schema mirrored from packages/*
        │
        ├── MarkdownStore   (files ⇄ Card, via gitkanban-core rules)   [pending in GitKit]
        └── SyncEngine      (orchestrates pull → commit → push)
                    │  calls only the protocol
                    ▼
             GitEngine  (protocol: clone / pullRebase / commit / push / status / fileHistory)
             ├── ShellGitEngine   (macOS — subprocess `git`)     ✅ implemented, tested
             └── Libgit2Engine    (iOS — embedded libgit2/HTTPS)  ⏳ pending (Phase-0 spike first)
```

`GitEngine` is the only thing that knows git; `MarkdownStore` is the only thing that knows the file
format. That separation is what lets the same board UI run on macOS shell-git and iOS libgit2
unchanged. `swift/GitKit` also carries the cross-cutting services `KeychainService` (implemented),
`GitHubOAuthService` (GitHub device-flow, implemented), and — pending extraction from GitFolder —
`FolderAccessService` (security-scoped bookmarks) and `ConfigStore`.

**Extraction status.** `swift/GitKit` is being populated *additively* from GitFolder's inline
`Services/`: shared code lands, GitFolder is repointed at it, and its inline copy is deleted — each
step verified by the macOS xcodebuild CI. Done: Keychain + OAuth (GitFolder runs on them).
In progress: `ShellGitEngine` wired into the app, `FolderAccessService`, `ConfigStore` (GITKIT-005).

## TypeScript source-of-truth ↔ Swift mirror

The board/config **contract** is TypeScript; Swift mirrors it. There is no code generation — the
Swift models are hand-mirrored and kept honest against the TS package's tested fixtures.

```txt
packages/gitkanban-core  (TypeScript — SOURCE OF TRUTH, Vitest-tested)
  types.ts         Lane, User, Epic, Priority, BoardConfig, ProjectConfig, EffectiveConfig, cards
  frontmatter.ts   parse/serialize YAML frontmatter, preserving unknown keys
  inheritance.ts   resolveEffectiveConfig(root, project): lanes REPLACE, vocabularies MERGE
  rank.ts          fractional rank keys (an insert rewrites one card)
  card.ts          read fields, map status → lane, group into ordered columns
  validation.ts    validate a card against its effective config
        │
        │  mirrored (by hand, checked against fixtures)
        ▼
Swift domain models in gitkanban-macos / (later) MarkdownStore in swift/GitKit
```

Design invariants enforced by the contract: **one card = one file** (editing a card never touches
another's bytes); **column = a field (`status`), not a folder** at the data layer; **additive and
lenient** — unknown frontmatter/config keys survive round-trips so agents and other tools can add
fields the app doesn't model. The canonical format is `project-assets/Tasks/README.md`.

**Caveat — `packages/core` (GitFolder).** Unlike `gitkanban-core`, GitFolder's `@gitfolder/core` is
currently **not consumed** by the shipping Swift app and has drifted from it (flagged by the
architecture audit: it models an SSH-only, richly-instrumented surface the app doesn't ship). So the
"TS is the source of truth" relationship is *realized* for GitKanban and *aspirational / under
reconciliation* for GitFolder (tracked: GITFOLDER-004 / GITFOLDER-010). Treat `docs/data-model.md`
as GitFolder's human contract until that is resolved.

## Build / test / CI topology

**Local commands** (root `package.json`):

```bash
npm install                  # install all JS/TS workspaces (one lockfile)
npm run check                # typecheck + test + build every workspace — exactly what CI runs
npm run gitkanban:core:test  # Vitest for packages/gitkanban-core
npm run site:dev             # run the website locally
npm run macos:generate       # XcodeGen: regenerate GitFolder's .xcodeproj
```

`npm run check` = `typecheck --workspaces --if-present && test … && build …`, so adding a workspace
needs no script change. Swift projects are generated from `project.yml` via XcodeGen and never
hand-edited.

**CI — four workflows** (`.github/workflows/`):

| Workflow | Runner | Trigger | Does |
|---|---|---|---|
| `check.yml` | ubuntu | push/PR to `main`,`development` | `npm ci` + `npm run check` (all TS workspaces) |
| `macos-native.yml` | macos-15 | push/PR to `main`,`development` | `xcodegen generate` → xcodebuild **test**, Release build, and archive-shape validation of GitFolder (unsigned) |
| `swift-gitkit.yml` | macos-15 | push/PR touching `swift/GitKit/**` | `swift build` + `swift test` of the GitKit package |
| `deploy-website.yml` | ubuntu | push to `main` touching `apps/website`/`packages`/root configs | `npm run site:build` → Cloudflare Pages deploy (`wrangler-action`) |

The macOS and swift-gitkit jobs are path/branch aware; `swift-gitkit` and `deploy-website` only run
when their inputs change. There is no signing in CI (`CODE_SIGNING_ALLOWED=NO`); signed archiving is
a local script (`npm run macos:archive:app-store`).

## Where plans vs code live

- **Code** — this repo (`apps/`, `packages/`, `swift/`).
- **Product plans, specs, audits, and the task board** — the separate `project-assets` repo:
  - GitFolder plans: `GitKit/Gitfolder/` (and mirrored into this repo's `docs/*.md`).
  - GitKanban plans: `GitKit/GitKanban/plan/` (architecture, platforms-and-git, data-model,
    sync-model, phases) — **not** duplicated into the code repo.
  - Task board: `Tasks/GitKit/` — cards carry `GITKIT-###` / `GITFOLDER-###` ids and an `epic:`
    (`gitfolder`, `gitkanban-core`, `gitkit-swift`, `gitkanban-macos`, `gitkanban-ios`,
    `monorepo-setup`); board mutations are committed and pushed.

## Referenced GitFolder plan docs (this repo's `docs/`)

These sit *below* this monorepo overview and describe GitFolder specifically:
`product-spec.md`, `implementation-plan.md`, `data-model.md`, `sync-model.md`, `github-access.md`,
`macos-permissions.md`, `app-store.md`, `phase-1.md`, `edge-cases.md`, `future-phases.md`.
