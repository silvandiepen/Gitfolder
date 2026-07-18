<script setup lang="ts">
/**
 * @component MarketingLayout
 * Shared layout for all GitKit marketing pages. Neutral umbrella shell (header +
 * footer); product pages set their own [data-app] on the page root to theme
 * content. Uses @sil/ui PillHeader and the GitKit mark.
 */
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { PillHeader } from '@sil/ui'
import type { PillHeaderAction, PillHeaderNavItem } from '@sil/ui'
import GitKitMark from './GitKitMark.vue'
import { githubRepoUrl } from '@/links'
import { useContent } from '@/i18n'

interface NavLink { label: string; to: string }
interface FooterLink { label: string; to?: string; href?: string; external?: boolean }
interface FooterColumn { heading: string; links: FooterLink[] }
interface CommonContent {
  brand: { name: string; tagline: string }
  nav: NavLink[]
  githubLabel: string
  skipToContent: string
  actions: { toLight: string; toDark: string }
  footer: { columns: FooterColumn[]; copy: string }
}

const t = useContent<CommonContent>('common')

const route = useRoute()
const isDark = ref(true)

const navItems = computed<PillHeaderNavItem[]>(() => [
  ...t.nav.map((n) => ({ label: n.label, to: n.to, exact: true })),
  { label: t.githubLabel, href: githubRepoUrl, external: true },
])

const actions = computed<PillHeaderAction[]>(() => [
  {
    label: isDark.value ? t.actions.toLight : t.actions.toDark,
    icon: isDark.value ? 'weather/sun-light-mode' : 'weather/moon-dark-mode',
    iconOnly: true,
    handler: toggleColorMode,
  },
])

function applyMode(mode: 'dark' | 'light') {
  // @sil/ui colour tokens key off [data-theme]; the pre-paint script also sets
  // [data-color-mode]. Keep both in sync.
  document.documentElement.setAttribute('data-color-mode', mode)
  document.documentElement.setAttribute('data-theme', mode)
}

function toggleColorMode() {
  isDark.value = !isDark.value
  const mode = isDark.value ? 'dark' : 'light'
  applyMode(mode)
  localStorage.setItem('gitkit-color-mode', mode)
}

onMounted(() => {
  const storedMode = localStorage.getItem('gitkit-color-mode')
  const currentMode = (storedMode || document.documentElement.getAttribute('data-color-mode') || 'dark') as 'dark' | 'light'
  isDark.value = currentMode === 'dark'
  applyMode(currentMode)
})

const year = new Date().getFullYear()
</script>

<template>
  <div class="mlayout">
    <a href="#main" class="skip-link">{{ t.skipToContent }}</a>

    <PillHeader
      :nav-items="navItems"
      :actions="actions"
      :current-path="route.path"
      brand-to="/"
      :brand-suffix="t.brand.name"
      :brand-aria-label="`${t.brand.name} — Home`"
      color-mode="auto"
      menu-icon="ui/menu"
      close-icon="ui/multiply-m"
      class="mlayout__pill-header"
    >
      <template #brand-mark>
        <GitKitMark class="mlayout__brand-mark" :size="24" :title="t.brand.name" />
      </template>
    </PillHeader>

    <main id="main" class="mlayout__main">
      <slot />
    </main>

    <footer class="mlayout__footer">
      <div class="mlayout__container mlayout__footer-inner">
        <div class="mlayout__footer-brand-col">
          <router-link to="/" class="mlayout__footer-brand">
            <GitKitMark class="mlayout__footer-mark" :size="20" :title="t.brand.name" />
            <span>{{ t.brand.name }}</span>
          </router-link>
          <p class="mlayout__footer-tagline">{{ t.brand.tagline }}</p>
        </div>

        <nav class="mlayout__footer-cols" aria-label="Footer">
          <div v-for="col in t.footer.columns" :key="col.heading" class="mlayout__footer-col">
            <h2 class="mlayout__footer-heading">{{ col.heading }}</h2>
            <template v-for="l in col.links" :key="l.label">
              <a v-if="l.external" :href="l.href" target="_blank" rel="noopener">{{ l.label }}</a>
              <router-link v-else :to="l.to!">{{ l.label }}</router-link>
            </template>
          </div>
        </nav>
      </div>

      <div class="mlayout__container mlayout__footer-base">
        <p class="mlayout__footer-copy">&copy; {{ year }} {{ t.footer.copy }}</p>
      </div>
    </footer>
  </div>
</template>

<style lang="scss">
.mlayout {
  min-height: 100vh;
  background: var(--color-background);
  display: flex;
  flex-direction: column;

  &__container {
    max-width: 1120px;
    margin: 0 auto;
    padding: 0 32px;
    width: 100%;

    @include mobile { padding: 0 20px; }
  }

  &__pill-header {
    --pill-header-position: fixed;
    --pill-header-padding: 14px clamp(16px, 4vw, 32px) 0;
    --pill-header-radius: 999px;
    --pill-header-brand-gap: 10px;
    color: var(--color-foreground);
  }

  &__brand-mark,
  &__footer-mark {
    color: currentColor;
    flex: 0 0 auto;
  }

  &__main {
    flex: 1;
    padding-top: 76px;
  }

  // ── Footer ─────────────────────────────────────────────────────────────
  &__footer {
    padding: var(--space-xl) 0 var(--space-l);
    border-top: var(--border-width) solid var(--color-border-light);
    margin-top: auto;
    background: var(--surface-raised);
  }

  &__footer-inner {
    display: grid;
    grid-template-columns: minmax(0, 1.4fr) minmax(0, 2fr);
    gap: var(--space-xl);
    padding-bottom: var(--space-l);

    @include tablet { grid-template-columns: 1fr; gap: var(--space-l); }
  }

  &__footer-brand {
    display: inline-flex;
    align-items: center;
    gap: var(--space-s);
    text-decoration: none;
    font-weight: var(--font-weight-bold);
    font-size: var(--font-size-m);
    color: var(--color-foreground);
  }

  &__footer-tagline {
    margin-top: var(--space-s);
    font-size: var(--font-size-s);
    color: var(--color-muted);
    max-width: 320px;
    line-height: var(--line-height-relaxed);
  }

  &__footer-cols {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: var(--space-l);

    @include mobile { grid-template-columns: repeat(2, 1fr); }
  }

  &__footer-col {
    display: flex;
    flex-direction: column;
    gap: var(--space-s);

    a {
      font-size: var(--font-size-s);
      color: var(--color-muted);
      text-decoration: none;
      transition: color var(--transition-fast);
      width: fit-content;

      &:hover { color: var(--color-foreground); }
    }
  }

  &__footer-heading {
    font-size: var(--font-size-xs);
    font-weight: var(--font-weight-semibold);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--color-subtle);
    margin-bottom: var(--space-xs);
  }

  &__footer-base {
    padding-top: var(--space-l);
    border-top: var(--border-width) solid var(--color-border-light);
  }

  &__footer-copy {
    font-size: var(--font-size-xs);
    color: var(--color-subtle);
  }
}

.pill-header__action--icon-only .pill-header__action-label,
.pill-header__action[aria-label*="Switch"] .pill-header__action-label {
  display: none;
}

@media (max-width: 720px) {
  .mlayout__main {
    padding-top: 84px;
  }
}
</style>
