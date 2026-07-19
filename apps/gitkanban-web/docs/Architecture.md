# GitKanban Web — Architecture

## Stack

- Vue 3 + Vite + TypeScript.
- Pinia stores for session, repositories, workspace, board state, and UI preferences.
- SCSS + BEM via `bemm`; `@sil/ui` tokens; no Tailwind and no scoped styles.
- `packages/gitkanban-core` for all board contract behavior.
- GitPont Worker as the intended auth/git boundary.
- Temporary bridge: direct GitHub OAuth/PAT and GitHub REST APIs until GitPont Worker exposes the
  write endpoints GitKanban needs.

## Data flow

```txt
Browser UI
  -> Pinia stores / services
  -> GitPont Worker
  -> GitPont core/provider APIs
  -> hosted git provider files

Browser UI
  -> packages/gitkanban-core
  -> parsed config/cards, columns, validation, ordering
```

The app should keep the same app boundary as macOS:

- UI components render state and emit user intent.
- Stores coordinate loaded repos/projects/boards and optimistic UI state.
- Services perform provider reads/writes through GitPont Worker. The current GitHub adapter is a
  temporary bridge.
- `packages/gitkanban-core` owns board semantics.

## Write model

Browser code cannot shell out to git. Writes should go through GitPont Worker endpoints backed by
`@git-pont/core`:

1. The app sends a provider-neutral file change request.
2. The worker resolves the user's session and connection.
3. GitPont core calls the relevant provider API.
4. The worker returns normalized commit/conflict/error data.

If the ref changed, the app must reload and show a "remote changed" recovery state rather than
silently overwriting.

Current bridge: GitKanban Web still uses GitHub Git Database APIs directly for create/edit/move/
delete until GitPont Worker exposes commit/delete/submit routes.

## Auth And Git Boundary

Production auth and repository access should use GitPont Worker:

- `GET /auth/github/start` starts provider OAuth.
- `GET /auth/github/callback` exchanges the code server-side, stores encrypted credentials, sets
  an HTTP-only session cookie, and redirects back to the app.
- `GET /session` restores returning users.
- `GET /repositories`, `/repos/:owner/:repo`, `/branches`, and `/contents/<path>` provide the
  provider-neutral read layer.

This moves secrets and refresh tokens out of the browser and lets the app support GitHub, GitLab,
Forgejo/Gitea, Codeberg, and Bitbucket through the same API as GitPont ports those providers.

Production GitPont Worker target should use:

- App origin: `https://kanban.hakobs.com`
- Worker OAuth callback: `https://<gitpont-worker-host>/auth/github/callback`
- Worker redirect back to app: `https://kanban.hakobs.com/`

## Native app detection and handoff

Use a custom URL scheme such as:

```txt
gitkanban://open?repo=owner/name&project=ProjectFolder&branch=main
```

Browser detection is inherently best-effort. The app should:

- Show the handoff action only after a lightweight capability check or after the user has opted in.
- Attempt the scheme on click.
- Use a short visibility/focus timeout to infer whether the native app opened.
- Keep the web app usable if the handoff fails.

The macOS app will need the scheme registered before detection can be reliable.

## Proposed folders

```txt
apps/gitkanban-web/
  src/
    app/
    components/
    features/
      auth/
      repos/
      projects/
      board/
      task-detail/
      native-handoff/
    services/
      github/
      board/
    stores/
    styles/
    types/
```
