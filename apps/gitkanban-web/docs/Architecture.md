# GitKanban Web — Architecture

## Stack

- Vue 3 + Vite + TypeScript.
- Pinia stores for session, repositories, workspace, board state, and UI preferences.
- SCSS + BEM via `bemm`; `@sil/ui` tokens; no Tailwind and no scoped styles.
- `packages/gitkanban-core` for all board contract behavior.
- GitHub REST APIs for repository contents, git object writes, refs, and commit history.
- GitHub OAuth/GitHub App authorization code flow with PKCE for browser sign-in.

## Data flow

```txt
Browser UI
  -> Pinia stores / services
  -> GitHub adapter
  -> GitHub repository files

Browser UI
  -> packages/gitkanban-core
  -> parsed config/cards, columns, validation, ordering
```

The app should keep the same app boundary as macOS:

- UI components render state and emit user intent.
- Stores coordinate loaded repos/projects/boards and optimistic UI state.
- Services perform GitHub reads/writes.
- `packages/gitkanban-core` owns board semantics.

## GitHub write model

Browser code cannot shell out to git. The web app should use GitHub's Git Database APIs for
multi-file commits:

1. Read the current branch ref.
2. Read the base commit/tree.
3. Create blobs for changed markdown files.
4. Create a new tree with file updates/deletions.
5. Create a commit with one logical action message.
6. Update the branch ref if it still points at the expected base.

If the ref changed, the app must reload and show a "remote changed" recovery state rather than
silently overwriting.

## Auth

The browser app uses GitHub authorization code flow with PKCE. It stores the PKCE verifier in
`sessionStorage` during the redirect, exchanges the returned code with the verifier, and then uses
the resulting user access token for GitHub API calls.

The app uses only the GitHub Client ID in source. A client secret must not be committed or shipped
to the browser.

For local development, the GitHub App callback URL must be `http://localhost:5173/`. By default
the web app does not send a `redirect_uri` parameter, so GitHub uses the callback URL configured
on the app.

Production is configured with `VITE_GITHUB_REDIRECT_URI=https://kanban.hakobs.com/` in
`.env.production`. Cloudflare Pages should map the `gitkanban-web` Pages project to
`kanban.hakobs.com`.

Fallback: allow a fine-grained PAT pasted into the browser, stored only in local browser storage
the user can clear.

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
