<script setup lang="ts">
/**
 * @component MarketingLayout
 * Shared layout for all marketing pages. Frosted header + content + footer.
 * Matches Kod's MarketingLayout pattern.
 */
import { useRoute } from 'vue-router'

const route = useRoute()
</script>

<template>
  <div class="mlayout">
    <header class="mlayout__header">
      <div class="mlayout__container mlayout__header-inner">
        <router-link to="/" class="mlayout__brand">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M12 2L2 7l10 5 10-5-10-5z"/>
            <path d="M2 17l10 5 10-5"/>
            <path d="M2 12l10 5 10-5"/>
          </svg>
          <span class="mlayout__brand-text">GitFolder</span>
        </router-link>
        <nav class="mlayout__nav">
          <router-link to="/docs">Docs</router-link>
          <router-link to="/privacy">Privacy</router-link>
          <router-link to="/support">Support</router-link>
          <a href="https://github.com/silvandiepen/Gitfolder" target="_blank" rel="noopener">GitHub</a>
          <button class="mlayout__color-toggle" @click="toggleColorMode" :aria-label="isDark ? 'Switch to light mode' : 'Switch to dark mode'">
            <svg v-if="isDark" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/></svg>
            <svg v-else width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>
          </button>
        </nav>
      </div>
    </header>

    <main class="mlayout__main">
      <slot />
    </main>

    <footer class="mlayout__footer">
      <div class="mlayout__container mlayout__footer-inner">
        <router-link to="/" class="mlayout__footer-brand">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M12 2L2 7l10 5 10-5-10-5z"/>
            <path d="M2 17l10 5 10-5"/>
            <path d="M2 12l10 5 10-5"/>
          </svg>
          <span>GitFolder</span>
        </router-link>
        <nav class="mlayout__footer-links">
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

<script lang="ts">
import { defineComponent } from 'vue'

export default defineComponent({
  data() {
    return {
      isDark: true,
    }
  },
  mounted() {
    this.isDark = document.documentElement.getAttribute('data-color-mode') === 'dark'
  },
  methods: {
    toggleColorMode() {
      this.isDark = !this.isDark
      const mode = this.isDark ? 'dark' : 'light'
      document.documentElement.setAttribute('data-color-mode', mode)
      localStorage.setItem('gitfolder-color-mode', mode)
    },
  },
})
</script>

<style lang="scss" scoped>
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

  @include e(header) {
    position: sticky;
    top: 0;
    z-index: 10;
    background: color-mix(in srgb, var(--color-surface), transparent 10%);
    backdrop-filter: blur(16px);
    -webkit-backdrop-filter: blur(16px);
    border-bottom: 1px solid var(--color-border-light);
  }

  @include e(header-inner) {
    display: flex;
    align-items: center;
    justify-content: space-between;
    height: 64px;
  }

  @include e(brand) {
    display: flex;
    align-items: center;
    gap: 10px;
    text-decoration: none;
    color: var(--color-text-primary);
  }

  @include e(brand-text) {
    font-weight: var(--font-weight-bold);
    font-size: var(--font-size-md);
  }

  @include e(nav) {
    display: flex;
    align-items: center;
    gap: 28px;

    a {
      font-size: var(--font-size-sm);
      font-weight: var(--font-weight-medium);
      color: var(--color-text-secondary);
      text-decoration: none;
      transition: color var(--transition-fast);
      padding: 4px 0;
      &:hover { color: var(--color-text-primary); }
      &.router-link-active { color: var(--color-accent); }
    }
  }

  @include e(color-toggle) {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 36px;
    height: 36px;
    border-radius: 50%;
    color: var(--color-text-secondary);
    transition: all var(--transition-fast);
    &:hover {
      color: var(--color-text-primary);
      background: var(--color-surface-raised);
    }
  }

  @include e(main) {
    flex: 1;
  }

  @include e(footer) {
    padding: 32px 0;
    border-top: 1px solid var(--color-border-light);
    margin-top: auto;
  }

  @include e(footer-inner) {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: 16px;
  }

  @include e(footer-brand) {
    display: flex;
    align-items: center;
    gap: 8px;
    text-decoration: none;
    font-weight: var(--font-weight-semibold);
    font-size: var(--font-size-sm);
    color: var(--color-text-primary);
  }

  @include e(footer-links) {
    display: flex;
    align-items: center;
    gap: 24px;

    a {
      font-size: var(--font-size-sm);
      color: var(--color-text-tertiary);
      text-decoration: none;
      transition: color var(--transition-fast);
      &:hover { color: var(--color-text-primary); }
    }
  }

  @include e(footer-copy) {
    font-size: var(--font-size-xs);
    color: var(--color-text-tertiary);
  }
}
</style>
