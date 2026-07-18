# Website — Agent Instructions

The GitKit marketing site: a **Vue 3 + Vite** SPA that covers the whole family — an umbrella
home page plus product pages for **GitFolder** (shipped) and **GitKanban** (coming soon) — and the
standard pages a site needs (docs, support, privacy, terms, sitemap, robots). Read the root
[`AGENTS.md`](../../AGENTS.md) first.

```bash
npm run site:dev        # from repo root — or `npm run dev` here
npm run typecheck       # vue-tsc
npm run build           # vite build (Rollup)
```

## Styling — @sil/ui tokens, BEM, no scoped styles

Per the root conventions: **SCSS + BEM (via `bemm`)**, no Tailwind, **no `<style scoped>`**, and
build on `@sil/ui` tokens. Concretely:

- **We adopt `@sil/ui`'s token + colour layer, not its full style bundle.** `main.scss` imports
  `@sil/ui/defaults` (colour tokens + dark/light via `[data-theme]`/`prefers-color-scheme`). We do
  **not** import `@sil/ui/styles` because its `app.scss` forces `height:100vh` + scroll-snap + a
  black-vignette `body` background meant for an app shell — it breaks a scrolling marketing site.
  `src/styles/_variables.scss` mirrors `@sil/ui`'s global token scale (`--space-*`,
  `--border-radius-*`, `--font-size-*`, `--font-weight-*`, `--transition*`, `--shadow-*`) so
  components can use those vars.
- **Never hardcode px / raw hex in component styles.** Use `var(--space-*)`, `var(--font-size-*)`,
  `var(--border-radius-*)`, `var(--color-*)`, etc. Brand hex lives in exactly one place —
  the palette block in `_variables.scss`.
- **Per-app theming:** the two brand colours are turquoise (GitFolder) and warm red (GitKanban);
  the shell is a neutral slate (GitKit). A page/section sets `data-app="gitfolder"` or
  `data-app="gitkanban"` on its root; `_variables.scss` remaps the generic `--color-accent*` tokens
  from that, so the shared `.mkt` primitives (`_marketing.scss`) theme themselves. For accent-
  coloured **text/icons** use `var(--accent-legible)` (flips to the light shade in dark mode);
  `--color-accent-dark` is for solid fills that carry `--color-light` text.
- Dark mode is toggled by writing **both** `data-theme` and `data-color-mode` on `<html>` (see
  `MarketingLayout.vue` + the pre-paint script in `index.html`); `@sil/ui` colour tokens key off
  `[data-theme]`.

## Content & i18n

All user-facing copy lives **outside components** so it can be translated (`src/i18n/`):

- **Structured UI copy → JSON:** `src/i18n/locales/<locale>/<namespace>.json`
  (`common`, `home`, `gitfolder`, `gitkanban`, `support`, `docs`). Read it with
  `useContent<T>('<namespace>')` from `@/i18n`.
- **Long-form prose → Markdown:** `src/i18n/pages/<locale>/<name>.md` (privacy, terms), read with
  `usePageMarkdown('<name>')` and rendered to HTML with **nizel** via `useMarkdown()`
  (`@/lib/useMarkdown`, backed by `nizel/browser`).
- Default locale is `en`; `locale` is a ref, so a language switcher can be added without moving
  content. Add a language = add a sibling folder.

## Gotchas

- **`@/composables`, `@/utils`, `@/common`, `@/mixins`, `@/stores`, `@/types` are aliased into
  `@sil/ui`'s own source by its Vite plugin.** Our composables therefore live in **`src/lib/`**
  (import `@/lib/...`), not `src/composables/`.
- **`Feature`/`Step` and other shared types live in `src/lib/content.ts`**, not exported from a
  `.vue` — vue-tsc's `*.vue` shim only default-exports.
- **`highlight.js` dev interop:** importing from the `@sil/ui` barrel pulls its Markdown component,
  which pulls `highlight.js` (CJS). esbuild mis-detects its default export during Vite dev
  pre-bundling, so `vite.config.ts` has `optimizeDeps.include: ['highlight.js/lib/core']`. The
  Rollup production build is unaffected.
