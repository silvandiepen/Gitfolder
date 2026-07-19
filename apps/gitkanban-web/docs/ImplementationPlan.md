# GitKanban Web — Implementation Plan

## Phase 0 — Contract and setup

- Scaffold the Vue/Vite workspace under `apps/gitkanban-web`.
- Add `@gitkit/gitkanban-core`, Vue, Pinia, `bemm`, `@sil/ui`, Nizel/markdown rendering, Vitest,
  and Playwright.
- Add app-local styles using existing website token conventions without importing website code.
- Add typed models for repository/session/UI state that wrap, not duplicate, `gitkanban-core`.

## Phase 1 — GitHub connection

- Implement GitHub OAuth with PKCE. Built.
- Keep PAT fallback for development and advanced use. Built.
- Implement repository listing and sign-out.
- Persist connected repos and last active project in browser storage.

## Phase 2 — Read-only board parity

- Load workspace config and projects from a selected GitHub repo.
- Parse project boards with `packages/gitkanban-core`.
- Build the familiar shell: repo/project sidebar, top toolbar, filter bar, lanes view, list view,
  backlog panel, uncategorised column, empty/error states.
- Add search and filters.

## Phase 3 — Writes

- Implement GitHub multi-file commit service. Built.
- Create task. Built.
- Update task detail fields/body while preserving unknown frontmatter. Built.
- Move cards between lanes and folders. Built.
- Reorder cards.
- Bulk move, assign, and delete.
- Add conflict/ref-change recovery UI.

## Phase 4 — Project settings

- Create project folder and README config.
- Edit lanes/priorities/types/users.
- Create missing lane folders.
- Migrate removed/renamed lanes.
- Unassign removed members.

## Phase 5 — History, handoff, polish

- Card history view via GitHub commits for the file path.
- Raw markdown, copy/export/download, and "Find on GitHub".
- Native-app URL-scheme handoff.
- Keyboard shortcuts matching macOS where browser-safe.
- Playwright coverage for auth fallback, board load, create/edit/move/reorder, conflict recovery,
  and handoff fallback.

## First implementation slice

The first code slice is built:

1. Scaffold the app.
2. Add GitHub OAuth with PKCE and PAT fallback.
3. List and search repositories.
4. Open a repo and render read-only boards by project.
5. Add filters/search, card detail, GitHub links, card history, and native handoff.
6. Run typecheck/build and a focused unit test around board-loader helpers.

## Next implementation slice

1. Deploy/configure GitPont Worker for `kanban.hakobs.com`.
2. Replace browser GitHub OAuth/session/repository reads with GitPont Worker endpoints.
3. Add GitPont Worker write endpoints for commit/delete/submit, backed by `@git-pont/core`.
4. Move GitKanban create/edit/move/delete/reorder onto those worker write endpoints.
5. Add project settings, precise drag reorder, bulk move/assign/delete, optimistic UI, and
   ref-change recovery.
