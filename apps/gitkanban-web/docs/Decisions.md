# GitKanban Web — Decisions

## 1. The web app is a new app, not the marketing site

Decision: build GitKanban Web under `apps/gitkanban-web/`.

Reason: `apps/website/` is the public marketing/docs site. The web version requested here is a
logged-in workspace with GitHub access, editing, and board state. Keeping it separate avoids
mixing marketing concerns with application state and auth.

## 2. Browser writes use GitHub APIs, not local git

Decision: use GitHub REST/Git Database APIs for v1 web writes.

Reason: browsers cannot shell out to git. A WASM git/OPFS clone may become useful later, but the
GitHub API path is the smallest real implementation that can create commits and push changes from
the browser.

## 3. Browser OAuth is a temporary bridge

Decision: use GitHub authorization code flow with PKCE as the primary browser sign-in path, with
fine-grained PAT as an advanced fallback, only until GitPont Worker is deployed for GitKanban.

Reason: a static SPA cannot safely hold a GitHub OAuth client secret, but PKCE is designed for
public clients. This was enough to unblock the first web slice, but it keeps provider credentials
in the browser and hardcodes GitHub as the provider. GitPont Worker is the long-term boundary.

## 4. Native app detection is best-effort

Decision: use a GitKanban custom URL scheme and treat detection as advisory.

Reason: browsers intentionally limit installed-app detection. The web app can attempt handoff and
infer success from focus/visibility, but it must always keep the web fallback available.

## 5. GitPont Worker becomes the web git/auth boundary

Decision: migrate GitKanban Web from direct GitHub browser OAuth/API calls to the GitPont
Cloudflare Worker service once the worker is deployed.

Reason: GitPont master now contains `@git-pont/core` and `@git-pont/worker`. The worker handles
provider OAuth server-side, stores encrypted credentials, returns an HTTP-only session cookie, and
exposes normalized repository/content endpoints. That is the right boundary for GitKanban Web:
the app stays provider-neutral while GitPont owns GitHub/GitLab/Forgejo/Gitea/Bitbucket auth and
provider API differences. The current direct GitHub adapter is a temporary bridge.

Open dependency: GitPont Worker currently exposes session, repository list, repository metadata,
branches, and content reads. GitPont core already has commit/delete/submit APIs, but the worker
does not expose write endpoints yet. GitKanban Web needs those worker routes before we can remove
the direct GitHub write path completely.
