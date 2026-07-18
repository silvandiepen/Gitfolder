# GitKit — Agent Instructions

Entry point for any agent (or human) working in this repo. Read this first, then the
per-app `AGENTS.md` for whichever app you're touching.

GitKit is a **monorepo for git-backed apps**: two products — **GitFolder** and **GitKanban** —
each targeting **macOS and iOS**, plus a marketing website, all sharing one git engine. Both
products are local-first, own-your-data, no-server apps that treat a git repository as the
source of truth.

## The four apps (+ site)

| App | Home | Platform | Status |
|---|---|---|---|
| GitFolder (macOS) | `apps/native-macos/` | SwiftUI/AppKit menu-bar app | Shipping (App Store) |
| GitFolder (iOS) | `apps/gitfolder-ios/` | SwiftUI (planned) | Roadmap — libgit2 spike + plan |
| GitKanban (macOS) | `apps/gitkanban-macos/` | SwiftUI board app | In development (scaffold) |
| GitKanban (iOS) | `apps/gitkanban-ios/` | SwiftUI (planned) | Roadmap — Phase 2 |
| Website | `apps/website/` | Vue 3 + Vite | Shipping |

Each app folder carries its own `AGENTS.md` and `docs/{Features,Decisions,Architecture}.md`.
When a per-app rule conflicts with this file, **the per-app file wins**.

## Repository layout

```txt
apps/
  native-macos/       GitFolder — macOS menu-bar app (SwiftUI/AppKit, XcodeGen)
  gitfolder-ios/      GitFolder — iOS app (planned; docs/spec only)
  gitkanban-macos/    GitKanban — macOS board app (scaffold)
  gitkanban-ios/      GitKanban — iOS app (planned; docs/spec only)
  website/            Marketing/docs site (Vue 3 + Vite)
packages/
  core/               @gitfolder/core — GitFolder's TypeScript config contract
  gitkanban-core/     @gitkit/gitkanban-core — GitKanban board schema + logic (TS, tested)
swift/
  GitKit/             Shared Swift package: GitEngine + app services (config, keychain, OAuth)
docs/                 Global GitKit docs + GitFolder product plans
```

**Dependency rule (hard):** apps depend on packages, **never on each other**. Shared logic
belongs in a package — `swift/GitKit` (Swift) or `packages/*` (TypeScript) — not a cross-app
import. TypeScript is the source of truth for the board/config contracts; the Swift apps mirror
those packages, they do not fork them.

## Where the plans and tasks live

- **Product plans & specs:** the `project-assets` repo under `GitKit/` (`GitKit/Gitfolder/`,
  `GitKit/GitKanban/plan/`). The code repo's `docs/` mirrors the GitFolder product docs.
- **Task board:** the `GitKit` board in `project-assets/Tasks/GitKit/` (canonical format:
  `project-assets/Tasks/README.md`). Cards carry a `GITKIT-###` or `GITFOLDER-###` id and an
  `epic:` (`gitfolder`, `gitkanban-core`, `gitkit-swift`, `gitkanban-macos`, `gitkanban-ios`,
  `monorepo-setup`). Every board mutation is committed and pushed.

## Build, test, run

```bash
npm install                 # install all JS/TS workspaces
npm run check               # typecheck + test + build every workspace (what CI runs)
npm run gitkanban:core:test # test the GitKanban core package
npm run site:dev            # run the website locally
npm run macos:generate      # regenerate the GitFolder Xcode project (XcodeGen)
```

Swift apps use **XcodeGen** — never hand-edit `.xcodeproj`; edit `project.yml` and regenerate.
CI (`.github/workflows/`): `check.yml` (npm), `macos-native.yml` (build+test GitFolder),
`swift-gitkit.yml` (GitKit package), `deploy-website.yml` (Cloudflare).

## Conventions

These derive from Sil's baseline conventions (`project-assets/Agents/`); the load-bearing ones:

### Hard rules — no exceptions
- **Never** add a `Co-Authored-By: Claude` (or any AI) trailer to commit messages.
- **Never** `git commit`, `git push`, or `deploy` without the user explicitly asking in the
  current turn. "Looks good"/silence is not permission. **Board** changes in `project-assets`
  are the one exception — the board contract requires mutations be committed and pushed.
- **Never mock** in place of a real implementation. Implement the real thing or say you can't.
- **Never work around errors** — no removing imports, catch-and-ignore, `@ts-ignore`,
  disabling a check, or deleting a failing test to go green. Fix the root cause.
- **Never commit secrets** — tokens, keychains, `.env`, certificates, private keys.
- **Never** force-push, skip hooks (`--no-verify`), or amend a commit you didn't create this session.

### Style
- **Conventional Commits**, always: `type(scope): imperative subject` (`feat`, `fix`, `chore`,
  `refactor`, `style`, `docs`, `test`, `release`). Scope = affected app/module. Body explains *why*.
- **Reuse before you build** — check for an existing component/util/package before adding a
  parallel one. Match the surrounding code's idiom.
- **TypeScript:** `strict: true`, `interface` over `type` for object shapes, avoid `any`,
  named exports for utils/services. 2-space indent, double quotes, semicolons.
- **Swift:** SwiftUI + `@Observable`; keep `AppModel` the single UI-facing state object;
  domain/services stay UI-agnostic so the same layer can back macOS and iOS.
- **Website CSS:** SCSS + BEM (via `bemm`), no Tailwind, no `<style scoped>`; use `@sil/ui`
  tokens — see `apps/website/AGENTS.md`.

### Priority order when trade-offs conflict
correctness/security/privacy > architecture clarity > maintainability > extensibility >
developer convenience. Avoid premature complexity; don't design for hypothetical requirements.

### Assumption discipline
When the spec doesn't cover something and you make a judgment call, record it — in the app's
`docs/Decisions.md` or the PR description, not silently.

## Branching

`main` and `development` are the CI-protected branches. Feature/agent work happens on a branch
(the repo uses `claude/*` branches) and lands via PR. Prefer the clean current shape of the
product over backwards-compat shims — these apps have no external API consumers yet.
