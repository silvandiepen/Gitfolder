<script setup lang="ts">
/**
 * @component MarketingLayout
 * Shared layout for all marketing pages. Uses @sil/ui PillHeader and the supplied GitFolder line mark.
 */
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { PillHeader } from '@sil/ui'
import type { PillHeaderAction, PillHeaderNavItem } from '@sil/ui'
import GitFolderMark from './GitFolderMark.vue'

const route = useRoute()
const isDark = ref(true)

const navItems: PillHeaderNavItem[] = [
  { label: 'Docs', to: '/docs', exact: true },
  { label: 'Privacy', to: '/privacy', exact: true },
  { label: 'Support', to: '/support', exact: true },
  { label: 'GitHub', href: 'https://github.com/silvandiepen/Gitfolder', external: true },
]

const actions = computed<PillHeaderAction[]>(() => [
  {
    label: isDark.value ? 'Switch to light mode' : 'Switch to dark mode',
    icon: isDark.value ? 'weather/sun-light-mode' : 'weather/moon-dark-mode',
    iconOnly: true,
    handler: toggleColorMode,
  },
])

function toggleColorMode() {
  isDark.value = !isDark.value
  const mode = isDark.value ? 'dark' : 'light'
  document.documentElement.setAttribute('data-color-mode', mode)
  localStorage.setItem('gitfolder-color-mode', mode)
}

onMounted(() => {
  const storedMode = localStorage.getItem('gitfolder-color-mode')
  const currentMode = storedMode || document.documentElement.getAttribute('data-color-mode') || 'dark'
  isDark.value = currentMode === 'dark'
  document.documentElement.setAttribute('data-color-mode', currentMode)
})
</script>

<template>
  <div class="mlayout">
    <PillHeader
      :nav-items="navItems"
      :actions="actions"
      :current-path="route.path"
      brand-to="/"
      brand-suffix="GitFolder"
      brand-aria-label="GitFolder — Home"
      color-mode="auto"
      menu-icon="ui/menu"
      close-icon="ui/multiply-m"
      class="mlayout__pill-header"
    >
      <template #brand-mark>
        <GitFolderMark class="mlayout__brand-mark" :size="24" title="GitFolder" />
      </template>
    </PillHeader>

    <main class="mlayout__main">
      <slot />
    </main>

    <footer class="mlayout__footer">
      <div class="mlayout__container mlayout__footer-inner">
        <router-link to="/" class="mlayout__footer-brand">
          <GitFolderMark class="mlayout__footer-mark" :size="18" title="GitFolder" />
          <span>GitFolder</span>
        </router-link>
        <nav class="mlayout__footer-links" aria-label="Footer">
          <router-link to="/docs">Docs</router-link>
          <router-link to="/privacy">Privacy</router-link>
          <router-link to="/support">Support</router-link>
          <a href="https://github.com/silvandiepen/Gitfolder" target="_blank" rel="noopener">GitHub</a>
        </nav>
        <p class="mlayout__footer-copy">&copy; {{ new Date().getFullYear() }} GitFolder</p>
      </div>
    </footer>
  </div>
</template>

<style lang="scss">
.mlayout {
  min-height: 100vh;
  background: var(--color-bg);
  display: flex;
  flex-direction: column;

  &__container {
    max-width: 1120px;
    margin: 0 auto;
    padding: 0 32px;
    width: 100%;
  }

  &__pill-header {
    --pill-header-position: fixed;
    --pill-header-padding: 14px clamp(16px, 4vw, 32px) 0;
    --pill-header-radius: 999px;
    --pill-header-brand-gap: 10px;
    color: var(--color-text-primary);
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

  &__footer {
    padding: 32px 0;
    border-top: 1px solid var(--color-border-light);
    margin-top: auto;
  }

  &__footer-inner {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: 16px;
  }

  &__footer-brand {
    display: flex;
    align-items: center;
    gap: 8px;
    text-decoration: none;
    font-weight: var(--font-weight-semibold);
    font-size: var(--font-size-sm);
    color: var(--color-text-primary);
  }

  &__footer-links {
    display: flex;
    align-items: center;
    gap: 24px;

    a {
      font-size: var(--font-size-sm);
      color: var(--color-text-tertiary);
      text-decoration: none;
      transition: color var(--transition-fast);

      &:hover {
        color: var(--color-text-primary);
      }
    }
  }

  &__footer-copy {
    font-size: var(--font-size-xs);
    color: var(--color-text-tertiary);
  }
}

.pill-header__action--icon-only .pill-header__action-label,
.pill-header__action[aria-label*="Switch"] .pill-header__action-label {
  display: none;
}

@media (max-width: 720px) {
  .mlayout {
    &__main {
      padding-top: 84px;
    }

    &__footer-inner {
      align-items: flex-start;
      flex-direction: column;
    }
  }
}
</style>
