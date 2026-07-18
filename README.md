# GitKit

**A monorepo for git-backed apps.** GitKit houses the apps that make git a quiet,
first-class backend for everyday work — and the shared engine they run on.

| App | What it is | Status |
|---|---|---|
| **GitFolder** | macOS menu-bar app that auto-versions selected folders to GitHub | Shipping (App Store) |
| **GitKanban** | macOS/iOS kanban board backed by a git repo of markdown files | In development |

Both are local-first, own-your-data, no-server apps that treat a git repository as the
source of truth. They share the same git plumbing, so it lives in one repo.

## Repository layout

```txt
apps/
  gitfolder-macos/    GitFolder — macOS menu-bar app (SwiftUI/AppKit, XcodeGen)
  gitkanban-macos/    GitKanban — macOS board app (scaffold)
  website/            Marketing/docs site (Vue 3 + Vite)
packages/
  core/               @gitfolder/core — GitFolder's TypeScript contract
  gitkanban-core/     @gitkit/gitkanban-core — GitKanban board schema + logic (TS, tested)
swift/
  GitKit/             Shared Swift package: the GitEngine and app services (scaffold)
docs/                 GitFolder product docs
```

> **Shared engine.** `swift/GitKit` is the shared Swift package both native apps depend on
> (git engine, config store, keychain, GitHub OAuth, folder access). Extracting GitFolder's
> inline services into it is tracked work — see the GitKit tasks board.

## GitFolder

Automatic version history for your folders. A macOS menu-bar app that versions selected
folders with GitHub on an interval, creating quiet snapshot commits when files change.

Docs: [product spec](docs/product-spec.md) · [data model](docs/data-model.md) ·
[implementation plan](docs/implementation-plan.md) · [sync model](docs/sync-model.md) ·
[App Store & business model](docs/app-store.md) · [phase 1](docs/phase-1.md) ·
[GitHub access](docs/github-access.md) · [macOS permissions](docs/macos-permissions.md) ·
[edge cases](docs/edge-cases.md) · [future phases](docs/future-phases.md)

## GitKanban

Your kanban board is a git repo. A native macOS/iOS kanban app backed by markdown files in a
git repository you own — full history, no server, portable by default. The board schema,
config inheritance, and card logic live in [`packages/gitkanban-core`](packages/gitkanban-core/),
and the full plan lives in the `project-assets` repo under `GitKit/GitKanban/plan/`.

The canonical board format is the shared Tasks contract (`project-assets/Tasks/README.md`):
root/project configuration with inheritance, and markdown cards with YAML frontmatter.

## Development

```bash
npm install                              # install all workspaces
npm run check                            # typecheck + test + build everything
npm run gitkanban:core:test              # test the GitKanban core
npm run macos:generate                   # regenerate the GitFolder Xcode project
```
