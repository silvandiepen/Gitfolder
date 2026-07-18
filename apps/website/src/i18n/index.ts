import { ref } from 'vue'

/**
 * Minimal, dependency-free i18n content loader.
 *
 * Content lives outside components so it can be translated:
 *   - Structured UI copy  → JSON in `locales/<locale>/<namespace>.json`
 *   - Long-form prose     → Markdown in `pages/<locale>/<name>.md` (rendered with nizel)
 *
 * Adding a language = adding a sibling folder. `locale` is a ref so a future
 * language switcher can flip it reactively; today it stays at DEFAULT_LOCALE.
 */

export const DEFAULT_LOCALE = 'en'
export const locale = ref(DEFAULT_LOCALE)

const jsonModules = import.meta.glob('./locales/*/*.json', {
  eager: true,
  import: 'default',
}) as Record<string, unknown>

const markdownModules = import.meta.glob('./pages/*/*.md', {
  eager: true,
  query: '?raw',
  import: 'default',
}) as Record<string, string>

/** Read a structured content namespace for the active locale (falls back to en). */
export function useContent<T = Record<string, unknown>>(namespace: string): T {
  const key = `./locales/${locale.value}/${namespace}.json`
  const fallback = `./locales/${DEFAULT_LOCALE}/${namespace}.json`
  const found = jsonModules[key] ?? jsonModules[fallback]
  if (!found) throw new Error(`Missing content namespace: ${namespace}`)
  return found as T
}

/** Read raw markdown for a long-form page in the active locale (falls back to en). */
export function usePageMarkdown(name: string): string {
  const key = `./pages/${locale.value}/${name}.md`
  const fallback = `./pages/${DEFAULT_LOCALE}/${name}.md`
  return (markdownModules[key] ?? markdownModules[fallback] ?? '') as string
}
