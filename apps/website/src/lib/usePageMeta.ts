import { watchEffect } from 'vue'
import { useRoute } from 'vue-router'
import { siteOrigin } from '@/links'

export interface PageMeta {
  /** Full document title. If omitted, the route meta title (via router) stands. */
  title: string
  /** Meta + OG description. */
  description: string
  /** Canonical path (defaults to the current route path). */
  path?: string
  /** Absolute OG image URL (defaults to the site social image). */
  image?: string
}

function upsertMeta(selector: string, attr: 'name' | 'property', key: string, content: string) {
  let el = document.head.querySelector<HTMLMetaElement>(selector)
  if (!el) {
    el = document.createElement('meta')
    el.setAttribute(attr, key)
    document.head.appendChild(el)
  }
  el.setAttribute('content', content)
}

function upsertCanonical(href: string) {
  let el = document.head.querySelector<HTMLLinkElement>('link[rel="canonical"]')
  if (!el) {
    el = document.createElement('link')
    el.setAttribute('rel', 'canonical')
    document.head.appendChild(el)
  }
  el.setAttribute('href', href)
}

/**
 * Lightweight per-page head management (title, description, canonical, OG/Twitter)
 * without pulling in a head-management dependency. Call once from a page's setup.
 */
export function usePageMeta(meta: PageMeta) {
  const route = useRoute()

  watchEffect(() => {
    const path = meta.path ?? route.path
    const url = `${siteOrigin}${path === '/' ? '' : path}`
    const image = meta.image ?? `${siteOrigin}/og-image.png`

    document.title = meta.title

    upsertMeta('meta[name="description"]', 'name', 'description', meta.description)
    upsertCanonical(url)

    upsertMeta('meta[property="og:type"]', 'property', 'og:type', 'website')
    upsertMeta('meta[property="og:title"]', 'property', 'og:title', meta.title)
    upsertMeta('meta[property="og:description"]', 'property', 'og:description', meta.description)
    upsertMeta('meta[property="og:url"]', 'property', 'og:url', url)
    upsertMeta('meta[property="og:image"]', 'property', 'og:image', image)

    upsertMeta('meta[name="twitter:card"]', 'name', 'twitter:card', 'summary_large_image')
    upsertMeta('meta[name="twitter:title"]', 'name', 'twitter:title', meta.title)
    upsertMeta('meta[name="twitter:description"]', 'name', 'twitter:description', meta.description)
    upsertMeta('meta[name="twitter:image"]', 'name', 'twitter:image', image)
  })
}
