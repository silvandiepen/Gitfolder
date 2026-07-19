# GitKanban Web — Features

GitKanban Web is the browser version of GitKanban: a GitHub-connected kanban board backed by the
same markdown task files and board config as the native apps.

## Built first slice

| Feature | Status |
|---|---|
| Vue/Vite app workspace | Built |
| GitHub OAuth with PKCE | Built |
| GitHub PAT sign-in fallback | Built |
| Repository listing and search | Built |
| Configurable board root path | Built |
| Workspace/project loading from GitHub repository contents | Built |
| Lanes and list views | Built |
| Assignee/priority/type filters and board search | Built |
| Card detail panel with editable fields/body | Built |
| Create task | Built |
| Delete task | Built |
| Move task to another lane | Built |
| GitHub blob link and commit history for a card path | Built |
| Best-effort `gitkanban://` native app handoff | Built |

Conflict recovery UI, project settings, bulk actions, and precise drag reorder are still planned.

## Current GitKanban functionality audit

| Surface | Location | Functionality observed |
|---|---|---|
| GitKanban macOS | `apps/gitkanban-macos/GitKanban/` | GitHub device-flow sign-in, token restore, repo list, app-owned checkout, multi-repo sidebar, project picker, project creation/settings, board lanes, list view, backlog docking, filters, search, task creation, task detail editing, markdown preview/raw view, drag-to-move, reorder, bulk move/assign/delete, card history, GitHub file links, refresh/pull/push status. |
| GitKanban iOS | `apps/gitkanban-ios/GitKanban/` | Early SwiftUI implementation exists despite docs saying planned: GitHub/provider-backed repo flow, project selection, list-style board, card edit sheet, new task sheet, delete via swipe, pull-to-refresh, saving indicator. It is smaller than macOS and touch-first. |
| GitKanban core | `packages/gitkanban-core/` | TypeScript source of truth for frontmatter parsing/serialization, body-section fields, config inheritance, rank helpers, validation, lane grouping, and card ordering. |
| Markdown webview | `apps/gitkanban-macos/webview/` | Nizel-powered markdown renderer bundled for the macOS `WKWebView`; useful precedent for browser markdown rendering, not an app shell. |
| Marketing website | `apps/website/` | Public Vue/Vite marketing site. It is not the GitKanban app and should not become the workspace UI. |

## Web v1 parity target

| Feature | Web behavior |
|---|---|
| GitHub connection | Sign in to GitHub with PKCE, list repositories, persist session locally, sign out cleanly. PAT fallback is built. |
| Repository opening | Open one or more GitHub repositories, remember connected repos, restore the last active repo/project. |
| Board loading | Read `Tasks/README.md`-style workspace config and project boards through `packages/gitkanban-core`. |
| Project navigation | Sidebar grouped by connected repo, project rows with lane/member metadata, add/switch/disconnect repo controls. |
| Board views | Familiar macOS layout: horizontal lanes, grouped list view, backlog docked bottom/right, uncategorised column. |
| Filters and search | Assignee/priority/type filters, clear filters, full-board search across title/id/body/assignee/type. |
| Task creation | Create a markdown card in the selected lane. Quick-create is built; full sheet with all fields is planned. |
| Task editing | Detail panel/window with editable title, lane, priority, type, assignee, markdown body, preview/raw markdown, GitHub link, history, export/download, delete. Editable fields/body, GitHub link, history, and delete are built; rendered preview/export are planned. |
| Movement and ordering | Drag/drop card moves, lane reordering, and bulk move/assign/delete. Lane move is built; precise reorder and bulk actions are planned. Writes must preserve unknown frontmatter keys. |
| Project settings | Create/edit project config: lanes, priorities, types, members, lane folders, lane migration, unassign removed members. |
| Git history | Show recent commits for a card path using GitHub commit APIs. |
| Sync/status | Surface loading/saving/pushing/error states. No silent conflict handling; failed ref updates require a visible recovery path. |
| Native app handoff | Detect likely installed app support, show "Open in GitKanban", attempt custom URL scheme, and fall back to the web board. |

## GitPont migration target

GitPont master now includes:

- `@git-pont/core`: provider-neutral TypeScript facade for OAuth, repository APIs, URL parsing,
  reads, commits, deletes, branch/PR submission, and normalized provider errors.
- `@git-pont/worker`: Cloudflare Worker service with OAuth, HTTP-only sessions, encrypted KV
  credential storage, repository listing, metadata, branches, content reads, profile storage, and
  CORS for web apps.

GitKanban Web should use GitPont Worker as the production boundary. That gives the web app a path
to GitHub, GitLab, self-hosted GitLab, Forgejo/Gitea, Codeberg, and Bitbucket without implementing
provider differences in the UI. Current direct GitHub browser auth/API code remains a temporary
bridge until GitPont Worker exposes write endpoints.

## Explicit non-goals for the first build

- No non-GitHub providers.
- No hosted GitKanban account.
- No realtime multiplayer or live cursors.
- No local filesystem clone in the browser for v1; GitHub is the backing transport.
- No marketing pages inside this app.
