# GitKanban Web — Agent Instructions

Read the root [`../../AGENTS.md`](../../AGENTS.md) first; this file adds GitKanban-web-specific
rules. If this file conflicts with the root file, this file wins for `apps/gitkanban-web/`.

## What this app is

GitKanban Web is the browser version of GitKanban: a Vue 3 + Vite app that opens a GitHub-backed
markdown task board and mirrors the macOS GitKanban product surface as closely as browser
constraints allow.

The web app is not the marketing site. It is the actual board workspace: GitHub connection,
repository/project picker, lanes/list views, task creation/editing, drag/reorder, search,
filters, history, and handoff to the installed macOS app when available.

## Rules specific to this app

- **Board logic comes from `packages/gitkanban-core`.** Do not reimplement parsing, grouping,
  inheritance, ordering, or validation in app code. Extend the package first if the web app needs
  new board behavior.
- **App code depends on packages, not other apps.** Do not import Swift code, the macOS webview,
  or website components directly. Shared browser logic belongs in `packages/*`.
- **No silent data loss.** All writes must preserve unknown frontmatter/config keys. A no-op
  read/write should remain a zero-diff operation.
- **GitHub is the v1 provider.** Any backend used for auth must be limited to token exchange and
  must not proxy board contents unless a future decision explicitly changes the product model.
- **Native-app handoff is first-class.** Detect support for the GitKanban URL scheme where the
  browser allows it, offer "Open in GitKanban", and fall back to the web workspace without blocking.

## Frontend conventions

- Vue 3 + Composition API + `<script setup lang="ts">`.
- Vite, TypeScript strict mode, Pinia for app state, Vue Router only when routes are needed.
- SCSS + BEM via `bemm`; no Tailwind; no `<style scoped>`.
- Use `@sil/ui` tokens and existing packages before creating one-off primitives.
- Components/composables use Sil's folder scaffold from `/Users/silvandiepen/Projects/Agents`.

## Planned commands

```bash
npm run dev -w apps/gitkanban-web
npm run typecheck -w apps/gitkanban-web
npm test -w apps/gitkanban-web
npm run build -w apps/gitkanban-web
```

