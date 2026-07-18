# GitFolder (macOS) — Agent Instructions

Read the root `../../AGENTS.md` first; this file adds GitFolder-macOS-specific
rules. Global hard rules (no AI commit trailers, never commit/push/deploy without
an explicit ask, never mock, never work around errors, never commit secrets) live
there and are not repeated here.

## What this app is

GitFolder for macOS: a shipping (App Store-targeted) SwiftUI/AppKit **menu-bar**
app that auto-versions user-selected folders to GitHub on an interval via system
Git. Menu-bar-only (`LSUIElement`), local-first, no backend. See
`docs/Features.md`, `docs/Architecture.md`, `docs/Decisions.md`.

## Where things live

- **Code:** `apps/gitfolder-macos/GitFolder/` — `App/` (`GitFolderApp`, `AppModel`),
  `Services/`, `Models/`, `Views/`. Tests in `apps/gitfolder-macos/Tests/`.
- **Shared Swift:** `../../swift/GitKit` — `KeychainService`, `GitHubOAuthService`
  (consumed today); `GitEngine`/`ShellGitEngine` and further extractions in
  progress. Put cross-app logic here, not in the app.
- **App docs:** `apps/gitfolder-macos/docs/{Features,Decisions,Architecture}.md`.
- **Product plans:** repo `docs/` (product-spec, sync-model, data-model, …) —
  note several describe an SSH-first/aspirational design the app no longer
  matches; treat this app's `docs/` and the code as authoritative.
- **Tasks:** the `GitKit` board, `GITFOLDER-###` cards (epic `gitfolder`).

## Build / run / test

```bash
npm run macos:generate          # xcodegen generate (from repo root)
# or:  cd apps/gitfolder-macos && xcodegen generate
open apps/gitfolder-macos/GitFolder.xcodeproj   # then build/run in Xcode
```

- CI is `.github/workflows/macos-native.yml` (runs `xcodegen generate` +
  `xcodebuild test/build/archive` with `CODE_SIGNING_ALLOWED=NO` on `macos-15`).
- Tests run via `xcodebuild ... test`; the sync happy-path test spawns real `git`.

## XcodeGen rule (hard)

Edit **`project.yml`** and regenerate — **never** hand-edit `GitFolder.xcodeproj`
(it is generated and git-ignored). Dependencies (`GitKit`, `git-pont`),
entitlements, Info.plist keys, and signing all live in `project.yml`.

## App-specific gotchas

- **`AppModel` is the single UI-facing state object** (`@MainActor @Observable`);
  keep services UI-agnostic so the layer can back a future iOS app. Route UI
  intents through `AppModel`, not directly to services from views.
- **Secrets:** the GitHub token lives **only** in the Keychain, never in
  `config.json`. Tests assert the token is absent from encoded config and from
  `git` argv — don't regress this.
- **Git via argv, never a shell.** `GitRunner` uses a `Process` argument array;
  keep user-supplied repo URLs/branches out of any shell string.
- **`git-pont` is branch-pinned** in `project.yml` (mutable) — don't rely on
  reproducible resolution until it's pinned to a tag/commit (GITFOLDER-006).
- **Sandbox vs. system git is unresolved** (GITFOLDER-001): the app is sandboxed
  but shells out to out-of-container `git`/`ssh`. Don't assume MAS-submittable.
- **Known gaps not to mistake for bugs to "fix" silently:** no pre-push safety
  scan (GITFOLDER-002), `conflict`/`needs_attention` states never produced
  (GITFOLDER-003), SSH auth has no UI / dead code (GITFOLDER-019), no config
  migration (GITFOLDER-017), no local logs despite the modeled `LogEntry`. These
  are tracked decisions — check the card before acting.
- **`SettingsView.swift` is a large multi-purpose file** with duplicated OAuth /
  branch-loading orchestration (GITFOLDER-018); prefer consolidating over adding
  a third copy.
- This app was renamed `native-macos` → `gitfolder-macos` (GITKIT-007); older
  branches, PRs, and the top-level `docs/` plans may still say `native-macos`.
