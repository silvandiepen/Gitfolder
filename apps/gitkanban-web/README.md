# GitKanban Web

Browser workspace for GitKanban.

**Status: first slice built.** The app now runs as a Vue/Vite workspace with GitHub OAuth/PAT
connection, repository search, configurable board root, project sidebar, lanes/list
views, search/filters, card detail editing, task creation, delete, lane moves, GitHub file links,
card history, and native-app URL-scheme handoff.

```bash
npm run dev -w apps/gitkanban-web
npm run typecheck -w apps/gitkanban-web
npm test -w apps/gitkanban-web
npm run build -w apps/gitkanban-web
```

## GitHub OAuth setup

For local development, the GitHub App callback URL must be:

```txt
http://localhost:5173/
```

By default the web app does not send a `redirect_uri` parameter; GitHub uses the callback URL
configured on the app. The browser OAuth flow uses the Client ID with PKCE. Do not put the client
secret in `.env` or source code.

For production, the app is configured for:

```txt
https://kanban.hakobs.com/
```

The GitHub App callback URLs should include both local and production if the app settings allow
multiple callbacks:

```txt
http://localhost:5173/
https://kanban.hakobs.com/
```

Cloudflare Pages deployment is handled by `.github/workflows/deploy-gitkanban-web.yml` and deploys
`apps/gitkanban-web/dist` to the `gitkanban-web` Pages project. Configure the Pages custom domain
`kanban.hakobs.com` in Cloudflare for that project.

Read in order:

1. [`docs/Features.md`](./docs/Features.md)
2. [`docs/Architecture.md`](./docs/Architecture.md)
3. [`docs/ImplementationPlan.md`](./docs/ImplementationPlan.md)
4. [`docs/Decisions.md`](./docs/Decisions.md)

Next build phase: project settings, bulk actions, precise drag reorder, and conflict recovery UI.
