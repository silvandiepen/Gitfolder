<script setup lang="ts">
/**
 * @component FeatureGrid
 * Shared feature card grid used by the home + product pages. Themed by the
 * nearest [data-app] via --color-accent*. Icons are feather-style line glyphs
 * referenced by name; unknown names fall back to a generic dot.
 */
import type { Feature } from '@/lib/content'

defineProps<{ features: Feature[] }>()
</script>

<template>
  <ul class="mkt__grid feature-grid" role="list">
    <li v-for="f in features" :key="f.title" class="mkt__card">
      <div class="mkt__card-icon" aria-hidden="true">
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <template v-if="f.icon === 'folder'"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/></template>
          <template v-else-if="f.icon === 'github'"><path d="M9 19c-5 1.5-5-2.5-7-3m14 6v-3.87a3.37 3.37 0 0 0-.94-2.61c3.14-.35 6.44-1.54 6.44-7A5.44 5.44 0 0 0 20 4.77 5.07 5.07 0 0 0 19.91 1S18.73.65 16 2.48a13.38 13.38 0 0 0-7 0C6.27.65 5.09 1 5.09 1A5.07 5.07 0 0 0 5 4.77a5.44 5.44 0 0 0-1.5 3.78c0 5.42 3.3 6.61 6.44 7A3.37 3.37 0 0 0 9 18.13V22"/></template>
          <template v-else-if="f.icon === 'clock'"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></template>
          <template v-else-if="f.icon === 'shield'"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></template>
          <template v-else-if="f.icon === 'terminal'"><polyline points="4 17 10 11 4 5"/><line x1="12" y1="19" x2="20" y2="19"/></template>
          <template v-else-if="f.icon === 'menu'"><line x1="3" y1="12" x2="21" y2="12"/><line x1="3" y1="6" x2="21" y2="6"/><line x1="3" y1="18" x2="21" y2="18"/></template>
          <template v-else-if="f.icon === 'columns'"><rect x="3" y="4" width="5" height="16" rx="1"/><rect x="9.5" y="4" width="5" height="10" rx="1"/><rect x="16" y="4" width="5" height="13" rx="1"/></template>
          <template v-else-if="f.icon === 'file'"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="8" y1="13" x2="16" y2="13"/><line x1="8" y1="17" x2="13" y2="17"/></template>
          <template v-else-if="f.icon === 'history'"><path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><polyline points="3 3 3 8 8 8"/><polyline points="12 7 12 12 15 14"/></template>
          <template v-else-if="f.icon === 'git-branch'"><line x1="6" y1="3" x2="6" y2="15"/><circle cx="18" cy="6" r="3"/><circle cx="6" cy="18" r="3"/><path d="M18 9a9 9 0 0 1-9 9"/></template>
          <template v-else-if="f.icon === 'bot'"><rect x="3" y="8" width="18" height="12" rx="2"/><path d="M12 8V4"/><circle cx="8.5" cy="14" r="1"/><circle cx="15.5" cy="14" r="1"/><path d="M2 13h1M21 13h1"/></template>
          <template v-else-if="f.icon === 'check'"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></template>
          <template v-else-if="f.icon === 'refresh'"><polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/></template>
          <template v-else-if="f.icon === 'lock'"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></template>
          <template v-else-if="f.icon === 'users'"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/></template>
          <template v-else><circle cx="12" cy="12" r="4"/></template>
        </svg>
      </div>
      <h3 class="mkt__card-title">{{ f.title }}</h3>
      <p class="mkt__card-desc">{{ f.desc }}</p>
    </li>
  </ul>
</template>

<style lang="scss">
.feature-grid {
  // inherits .mkt__grid layout; list reset so it renders as cards
  padding: 0;
  margin: 0;
}
</style>
