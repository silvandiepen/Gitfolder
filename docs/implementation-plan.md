# Monorepo Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Build GitFolder as a paid Mac App Store utility with a native macOS app and a small docs/marketing website in one npm monorepo.

**Architecture:** Use an npm workspace monorepo for shared TypeScript contracts, the website, and build tooling. Keep the macOS app native SwiftUI/AppKit with XcodeGen under `apps/native-macos`. Shared data contracts live in `packages/core` as TypeScript source and documentation; Swift models mirror those contracts manually in Phase 1.

**Tech Stack:** npm workspaces, TypeScript, Vitest, Vue 3 + Vite for the website, SwiftUI/AppKit for macOS, XcodeGen for native project generation, GitHub Actions for validation, and Mac App Store distribution.

---

## Product decision

GitFolder v1 is a simple paid Mac App Store app:

- Price: €5
- Model: lifetime purchase
- No subscription
- No in-app purchases
- No trial in Phase 1
- No account system for licensing
- Distribution: Mac App Store only

This matters technically. We do not need a billing backend, license server, Paddle/Stripe, or account system. The App Store handles purchase and entitlement. The app can stay local-first.

## Target repository shape

```txt
Gitfolder/
├─ apps/
│  ├─ native-macos/
│  │  ├─ project.yml
│  │  ├─ README.md
│  │  ├─ GitFolder/
│  │  │  ├─ App/
│  │  │  ├─ Models/
│  │  │  ├─ Services/
│  │  │  ├─ Views/
│  │  │  ├─ Resources/
│  │  │  ├─ GitFolder.entitlements
│  │  │  └─ Info.plist
│  │  └─ Tests/
│  └─ website/
│     ├─ index.html
│     ├─ package.json
│     ├─ vite.config.ts
│     ├─ tsconfig.json
│     ├─ public/
│     │  └─ _redirects
│     └─ src/
│        ├─ main.ts
│        ├─ App.vue
│        ├─ router.ts
│        ├─ pages/
│        ├─ data/
│        └─ styles/
├─ packages/
│  └─ core/
│     ├─ package.json
│     ├─ tsconfig.json
│     ├─ src/
│     │  ├─ index.ts
│     │  ├─ models.ts
│     │  ├─ defaults.ts
│     │  └─ validation.ts
│     └─ tests/
├─ docs/
│  ├─ product-spec.md
│  ├─ data-model.md
│  └─ implementation-plan.md
├─ .github/
│  └─ workflows/
│     ├─ check.yml
│     └─ macos-native.yml
├─ package.json
├─ package-lock.json
├─ tsconfig.base.json
└─ .gitignore
```

## Root scripts

The root `package.json` should expose boring scripts:

```json
{
  "scripts": {
    "check": "npm run typecheck --workspaces && npm test --workspaces && npm run build --workspaces",
    "typecheck": "npm run typecheck --workspaces --if-present",
    "test": "npm run test --workspaces --if-present",
    "build": "npm run build --workspaces --if-present",
    "site:dev": "npm run dev -w apps/website",
    "site:build": "npm run build -w apps/website",
    "core:build": "npm run build -w packages/core",
    "macos:generate": "cd apps/native-macos && xcodegen generate"
  },
  "workspaces": [
    "apps/*",
    "packages/*"
  ]
}
```

Use Node 22+ for every npm/Vite/TypeScript command.

---

# Phase 0: Repo conversion to npm monorepo

### Task 1: Add root npm workspace files

**Objective:** Turn the docs repo into an npm monorepo without adding app implementation yet.

**Files:**

- Create: `package.json`
- Create: `tsconfig.base.json`
- Create: `.gitignore`
- Create: `.editorconfig`

**Implementation notes:**

Root `package.json`:

```json
{
  "name": "gitfolder-monorepo",
  "private": true,
  "type": "module",
  "engines": {
    "node": ">=22"
  },
  "workspaces": [
    "apps/*",
    "packages/*"
  ],
  "scripts": {
    "check": "npm run typecheck --workspaces --if-present && npm test --workspaces --if-present && npm run build --workspaces --if-present",
    "typecheck": "npm run typecheck --workspaces --if-present",
    "test": "npm run test --workspaces --if-present",
    "build": "npm run build --workspaces --if-present",
    "site:dev": "npm run dev -w apps/website",
    "site:build": "npm run build -w apps/website",
    "core:build": "npm run build -w packages/core",
    "macos:generate": "cd apps/native-macos && xcodegen generate"
  }
}
```

`.gitignore` should include:

```gitignore
node_modules/
**/node_modules/
dist/
**/dist/
coverage/
.DS_Store
.env
.env.*
!.env.example
*.tgz
apps/native-macos/*.xcodeproj/
apps/native-macos/DerivedData/
apps/native-macos/build/
```

**Validation:**

```bash
node -v
npm install --package-lock-only
npm run check
```

Expected: no workspaces yet or empty pass after packages are added.

**Commit:**

```bash
git add package.json package-lock.json tsconfig.base.json .gitignore .editorconfig
git commit -m "chore: set up npm monorepo"
```

### Task 2: Add core package scaffold

**Objective:** Create shared TypeScript contracts for docs, validation, and future website use.

**Files:**

- Create: `packages/core/package.json`
- Create: `packages/core/tsconfig.json`
- Create: `packages/core/src/index.ts`
- Create: `packages/core/src/models.ts`
- Create: `packages/core/src/defaults.ts`
- Create: `packages/core/src/validation.ts`
- Create: `packages/core/tests/validation.test.ts`

**Implementation notes:**

The first package should not try to run Git. It only owns types, defaults, and config validation.

Core exports:

```ts
export * from './models.js'
export * from './defaults.js'
export * from './validation.js'
```

Use Vitest for validation tests.

**Validation:**

```bash
npm install
npm run typecheck -w packages/core
npm test -w packages/core
npm run build -w packages/core
```

**Commit:**

```bash
git add packages/core package.json package-lock.json
git commit -m "feat: add core data contracts"
```

---

# Phase 1: Native macOS app foundation

### Task 3: Add native macOS folder scaffold

**Objective:** Add the native app folder and XcodeGen project configuration.

**Files:**

- Create: `apps/native-macos/project.yml`
- Create: `apps/native-macos/README.md`
- Create: `apps/native-macos/GitFolder/Info.plist`
- Create: `apps/native-macos/GitFolder/GitFolder.entitlements`
- Create: `apps/native-macos/GitFolder/App/GitFolderApp.swift`
- Create: `apps/native-macos/GitFolder/App/AppModel.swift`

**Implementation notes:**

Use a native macOS app, not Electron. It needs real macOS folder permissions, status bar behavior, App Store signing, and security-scoped bookmarks.

Xcode target:

- Platform: macOS
- Minimum macOS: 14.0 or newer
- UI: SwiftUI with AppKit `NSStatusItem` bridge
- Bundle ID: `app.gitfolder.GitFolder` or another final App Store-ready ID
- Team ID: Sil's Apple team when signing later

Do not commit generated `.xcodeproj`.

**Validation:**

```bash
cd apps/native-macos
xcodegen generate
```

On VPS/Linux, only validate file shape. Real build happens in macOS GitHub Actions or on a Mac.

**Commit:**

```bash
git add apps/native-macos .gitignore package.json
git commit -m "feat: scaffold native macos app"
```

### Task 4: Implement menu bar shell

**Objective:** Make the app live in the macOS menu bar with basic actions.

**Files:**

- Create: `apps/native-macos/GitFolder/Services/StatusBarController.swift`
- Create: `apps/native-macos/GitFolder/Views/Menu/MenuContentView.swift`
- Modify: `apps/native-macos/GitFolder/App/GitFolderApp.swift`
- Modify: `apps/native-macos/GitFolder/App/AppModel.swift`

**Required menu:**

```txt
GitFolder
├─ Sync Now
├─ Pause Syncing
├─ Folders
│  └─ Add Folder…
├─ Settings…
├─ Logs
└─ Quit GitFolder
```

**Validation:**

Build/run on macOS and confirm no main window opens by default.

**Commit:**

```bash
git add apps/native-macos
git commit -m "feat: add menu bar shell"
```

### Task 5: Implement local config storage

**Objective:** Store app settings and synced folders locally.

**Files:**

- Create: `apps/native-macos/GitFolder/Models/GitFolderConfig.swift`
- Create: `apps/native-macos/GitFolder/Models/SyncedFolder.swift`
- Create: `apps/native-macos/GitFolder/Services/ConfigStore.swift`
- Create: `apps/native-macos/Tests/ConfigStoreTests.swift`

**Rules:**

- Store JSON in Application Support.
- Include `schemaVersion`.
- Write atomically.
- Back up invalid config instead of deleting it.

**Validation:**

Run native tests in Xcode or macOS CI.

**Commit:**

```bash
git add apps/native-macos
git commit -m "feat: add local config storage"
```

### Task 6: Implement folder picker and bookmarks

**Objective:** Let the user select folders and preserve access after restart.

**Files:**

- Create: `apps/native-macos/GitFolder/Services/FolderAccessService.swift`
- Create: `apps/native-macos/GitFolder/Views/Folders/AddFolderView.swift`
- Modify: `apps/native-macos/GitFolder/Models/SyncedFolder.swift`

**Rules:**

- Use native folder picker.
- Store security-scoped bookmark data if sandboxed.
- Call `startAccessingSecurityScopedResource()` before sync.
- Call `stopAccessingSecurityScopedResource()` afterward.

**Validation:**

Add a folder, restart app, verify folder access still works.

**Commit:**

```bash
git add apps/native-macos
git commit -m "feat: add folder access bookmarks"
```

### Task 7: Implement Git command runner

**Objective:** Wrap system Git calls with timeouts, captured output, and safe errors.

**Files:**

- Create: `apps/native-macos/GitFolder/Services/GitRunner.swift`
- Create: `apps/native-macos/GitFolder/Models/GitCommandResult.swift`
- Create: `apps/native-macos/Tests/GitRunnerTests.swift`

**Rules:**

- Use `/usr/bin/env git` or resolved Git path.
- Capture stdout/stderr.
- Set working directory explicitly.
- Never run shell-interpolated user input.
- Add timeouts.

**Validation:**

Test `git --version`, `git status --porcelain`, and failure handling in a temp directory.

**Commit:**

```bash
git add apps/native-macos
git commit -m "feat: add git command runner"
```

### Task 8: Implement repository inspection

**Objective:** Detect repo state before syncing.

**Files:**

- Create: `apps/native-macos/GitFolder/Services/RepositoryInspector.swift`
- Create: `apps/native-macos/GitFolder/Models/GitRepositoryState.swift`
- Create: `apps/native-macos/Tests/RepositoryInspectorTests.swift`

**Must detect:**

- not a Git repo
- remote mismatch
- branch mismatch
- uncommitted changes
- untracked files
- unpushed commits
- remote divergence
- merge in progress
- rebase in progress

**Validation:**

Use temp Git repos in tests.

**Commit:**

```bash
git add apps/native-macos
git commit -m "feat: inspect git repository state"
```

### Task 9: Implement safety scan

**Objective:** Warn before first sync for obvious sensitive files and huge folders.

**Files:**

- Create: `apps/native-macos/GitFolder/Services/SafetyScanner.swift`
- Create: `apps/native-macos/GitFolder/Models/FolderSafetyState.swift`
- Create: `apps/native-macos/Tests/SafetyScannerTests.swift`

**Minimum patterns:**

```txt
.env
.env.*
*.pem
*.key
id_rsa
id_ed25519
*.p12
*.sqlite
*.sqlite3
*.db
```

**Rules:**

- This is a warning system, not a perfect scanner.
- Do not upload/send file contents anywhere.
- Keep scanning local.

**Commit:**

```bash
git add apps/native-macos
git commit -m "feat: add folder safety scan"
```

### Task 10: Implement sync engine

**Objective:** Create snapshot commits and push safely.

**Files:**

- Create: `apps/native-macos/GitFolder/Services/SyncEngine.swift`
- Create: `apps/native-macos/GitFolder/Models/SyncRun.swift`
- Create: `apps/native-macos/Tests/SyncEngineTests.swift`

**Safe algorithm:**

```txt
For each enabled folder:
  1. Resolve folder access.
  2. Inspect repository state.
  3. Stop if merge/rebase/conflict/divergence exists.
  4. Fetch remote.
  5. Stop if remote changed in a way that is not safe.
  6. Check local changes.
  7. If no changes, mark synced/no changes.
  8. Debounce briefly.
  9. Check changes again.
  10. Stage allowed changes.
  11. Commit snapshot.
  12. Push.
  13. Update status and log result.
```

Do not auto-resolve conflicts. Do not force push.

**Commit:**

```bash
git add apps/native-macos
git commit -m "feat: add safe sync engine"
```

### Task 11: Implement scheduler and manual sync

**Objective:** Run sync on interval and from menu action.

**Files:**

- Create: `apps/native-macos/GitFolder/Services/SyncScheduler.swift`
- Modify: `apps/native-macos/GitFolder/Services/StatusBarController.swift`
- Modify: `apps/native-macos/GitFolder/App/AppModel.swift`

**Rules:**

- Only one sync per folder at a time.
- Respect global pause.
- Respect per-folder pause.
- Default interval: 15 minutes.

**Commit:**

```bash
git add apps/native-macos
git commit -m "feat: add sync scheduler"
```

### Task 12: Implement logs and user-facing errors

**Objective:** Give users clear status without dumping Git internals into the menu.

**Files:**

- Create: `apps/native-macos/GitFolder/Services/LogStore.swift`
- Create: `apps/native-macos/GitFolder/Models/UserFacingError.swift`
- Create: `apps/native-macos/GitFolder/Views/Logs/LogsView.swift`

**Rules:**

- User message: short and clear.
- Technical Git output: logs only.
- Store logs as JSON Lines.

**Commit:**

```bash
git add apps/native-macos
git commit -m "feat: add local logs"
```

---

# Phase 2: Website and docs

### Task 13: Add website scaffold

**Objective:** Create the static docs/marketing site.

**Files:**

- Create: `apps/website/package.json`
- Create: `apps/website/index.html`
- Create: `apps/website/vite.config.ts`
- Create: `apps/website/tsconfig.json`
- Create: `apps/website/src/main.ts`
- Create: `apps/website/src/router.ts`
- Create: `apps/website/src/App.vue`
- Create: `apps/website/src/styles/main.scss`
- Create: `apps/website/public/_redirects`

**Stack:**

- Vue 3
- Vite
- TypeScript
- SCSS
- Optional `@sil/ui` if we want Sil-family polish

**Validation:**

```bash
npm run typecheck -w apps/website
npm run build -w apps/website
```

**Commit:**

```bash
git add apps/website package.json package-lock.json
git commit -m "feat: scaffold docs website"
```

### Task 14: Add website pages

**Objective:** Provide enough public docs for a €5 Mac App Store utility.

**Files:**

- Create: `apps/website/src/pages/HomePage.vue`
- Create: `apps/website/src/pages/DocsIndexPage.vue`
- Create: `apps/website/src/pages/GettingStartedPage.vue`
- Create: `apps/website/src/pages/GitHubSshPage.vue`
- Create: `apps/website/src/pages/SafetyPage.vue`
- Create: `apps/website/src/pages/TroubleshootingPage.vue`
- Create: `apps/website/src/pages/PrivacyPage.vue`
- Create: `apps/website/src/pages/SupportPage.vue`

**Required public copy:**

- “Automatic version history for your folders.”
- “One-time €5 purchase on the Mac App Store.”
- “No subscription.”
- “Uses your existing GitHub SSH setup.”
- “Your files go to repositories you choose. GitFolder does not run a cloud sync service.”

**Validation:**

Build and route-smoke direct URLs with Vite preview or static server.

**Commit:**

```bash
git add apps/website
git commit -m "feat: add website docs pages"
```

### Task 15: Add App Store support/privacy docs

**Objective:** Prepare public URLs required by App Store review.

**Files:**

- Create: `docs/app-store.md`
- Ensure website routes exist: `/privacy`, `/support`

**Privacy stance:**

- No account in Phase 1.
- No analytics unless deliberately added later.
- No custom backend.
- User-selected folders are read locally.
- File contents are committed to the GitHub repositories the user configures.
- GitFolder does not receive file contents.

**Commit:**

```bash
git add docs/app-store.md apps/website/src/pages/PrivacyPage.vue apps/website/src/pages/SupportPage.vue
 git commit -m "docs: add app store support and privacy notes"
```

---

# Phase 3: CI/CD

### Task 16: Add cheap npm CI

**Objective:** Validate TypeScript packages and website on every PR/push.

**Files:**

- Create: `.github/workflows/check.yml`

**Workflow:**

- checkout
- setup Node 22
- `npm ci`
- `npm run check`

**Commit:**

```bash
git add .github/workflows/check.yml
 git commit -m "ci: add npm checks"
```

### Task 17: Add manual macOS native CI

**Objective:** Validate the native app without wasting macOS minutes on every push.

**Files:**

- Create: `.github/workflows/macos-native.yml`

**Workflow:**

- `workflow_dispatch` only at first
- require confirmation input such as `BUILD_MACOS`
- setup XcodeGen
- generate project
- run `xcodebuild` with code signing disabled for simulator/local validation where possible

**Commit:**

```bash
git add .github/workflows/macos-native.yml
 git commit -m "ci: add manual macos build"
```

### Task 18: Add website deployment later

**Objective:** Deploy docs site through GitHub Actions, not from the VPS.

**Files:**

- Create later: `.github/workflows/deploy-website.yml`

**Notes:**

Cloudflare Pages is fine for the website, but this can wait until the site exists. Do not direct-deploy from the VPS unless explicitly requested.

---

# Phase 4: App Store readiness

### Task 19: Prepare App Store metadata

**Objective:** Collect the copy and URLs needed for review.

**Files:**

- Create: `docs/app-store.md`
- Create: `assets/app-store/README.md`

**Metadata draft:**

- Name: GitFolder
- Subtitle: Automatic Git snapshots for folders
- Price: €5 one-time
- Category: Developer Tools or Productivity
- Privacy Policy URL: website `/privacy`
- Support URL: website `/support`

**Short description:**

```txt
GitFolder is a small Mac menu bar app that automatically versions selected folders with GitHub. Pick a folder, connect a repository, choose an interval, and let GitFolder create quiet snapshot commits in the background.
```

### Task 20: Add signing/notarization/App Store pipeline

**Objective:** Package and upload the app through the proper Apple path.

**Files:**

- Modify: `.github/workflows/macos-native.yml`
- Add secure GitHub secrets later for Apple signing/upload

**Rules:**

- Do not store Apple credentials in the repo.
- Do not direct-distribute outside the App Store for v1.
- Use App Store Connect/TestFlight before release.

---

## First build milestone

The first useful milestone is not the website. It is a local native app that can safely snapshot one folder.

Milestone acceptance criteria:

1. App opens only in menu bar.
2. User can add one folder.
3. User can enter one SSH GitHub repo URL.
4. App tests `git ls-remote` successfully.
5. App initializes Git if needed.
6. App warns about obvious sensitive/large files before first sync.
7. Manual “Sync Now” creates one commit and pushes it.
8. Conflicts/divergence pause the folder instead of trying to fix it.
9. Logs show technical output.
10. User-facing status stays simple.

## What not to build in v1

Do not build these yet:

- OAuth
- repository picker
- creating GitHub repos from the app
- subscriptions
- license server
- custom backend
- restore UI
- diff UI
- merge conflict resolver
- GitLab/Bitbucket support
- team collaboration
- Windows/Linux app

Keep it boring. That is how this ships.
