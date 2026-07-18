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

## 3. OAuth uses PKCE in the browser

Decision: use GitHub authorization code flow with PKCE as the primary browser sign-in path, with
fine-grained PAT as an advanced fallback.

Reason: a static SPA cannot safely hold a GitHub OAuth client secret, but PKCE is designed for
public clients. The app stores only the Client ID in source. A Worker remains optional later if we
want server-managed token storage, but it is not required for the first production OAuth path.

## 4. Native app detection is best-effort

Decision: use a GitKanban custom URL scheme and treat detection as advisory.

Reason: browsers intentionally limit installed-app detection. The web app can attempt handoff and
infer success from focus/visibility, but it must always keep the web fallback available.
