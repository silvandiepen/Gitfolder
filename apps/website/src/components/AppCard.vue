<script setup lang="ts">
/**
 * @component AppCard
 * Home-page card for one product. Sets [data-app] so it themes itself to the
 * product's brand colour via --color-accent*.
 */
import GitFolderMark from './GitFolderMark.vue'
import GitKanbanMark from './GitKanbanMark.vue'

defineProps<{
  app: 'gitfolder' | 'gitkanban'
  name: string
  tagline: string
  points: string[]
  to: string
  cta: string
  badge?: string
}>()
</script>

<template>
  <article class="app-card" :data-app="app">
    <div class="app-card__head">
      <span class="app-card__mark" aria-hidden="true">
        <GitFolderMark v-if="app === 'gitfolder'" :size="60" />
        <GitKanbanMark v-else :size="60" />
      </span>
      <span v-if="badge" class="mkt__badge">{{ badge }}</span>
    </div>

    <h3 class="app-card__name">{{ name }}</h3>
    <p class="app-card__tagline">{{ tagline }}</p>

    <ul class="app-card__points" role="list">
      <li v-for="p in points" :key="p">
        <svg class="app-card__tick" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"/></svg>
        <span>{{ p }}</span>
      </li>
    </ul>

    <RouterLink :to="to" class="mkt__btn-pill app-card__cta">
      {{ cta }}
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
    </RouterLink>
  </article>
</template>

<style lang="scss">
.app-card {
  position: relative;
  display: flex;
  flex-direction: column;
  padding: var(--space-l);
  border-radius: var(--border-radius-xxl);
  background: var(--surface);
  border: var(--border-width) solid var(--color-border-light);
  overflow: hidden;
  transition: border-color var(--transition), transform var(--transition), box-shadow var(--transition);

  // Brand-tinted top accent bar.
  &::before {
    content: '';
    position: absolute;
    inset: 0 0 auto 0;
    height: 5px;
    background: linear-gradient(90deg, var(--color-accent), var(--color-accent-light));
  }

  &:hover {
    transform: translateY(-3px);
    border-color: color-mix(in srgb, var(--color-accent) 45%, var(--color-border));
    box-shadow: var(--shadow-l);
  }

  &__head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: var(--space);
  }

  &__mark {
    display: inline-flex;
    box-shadow: var(--shadow-s);
    border-radius: 22%;
  }

  &__name {
    font-size: var(--font-size-xl);
    font-weight: var(--font-weight-bold);
    letter-spacing: -0.02em;
    margin-bottom: var(--space-xs);
  }

  &__tagline {
    font-size: var(--font-size);
    color: var(--color-muted);
    line-height: var(--line-height-relaxed);
    margin-bottom: var(--space);
  }

  &__points {
    display: flex;
    flex-direction: column;
    gap: var(--space-s);
    margin: 0 0 var(--space-l);
    padding: 0;

    li {
      display: flex;
      align-items: flex-start;
      gap: var(--space-s);
      font-size: var(--font-size-s);
      color: var(--color-foreground);
      line-height: var(--line-height-normal);
    }
  }

  &__tick {
    flex: 0 0 auto;
    margin-top: var(--space-xs);
    color: var(--accent-legible);
  }

  &__cta {
    margin-top: auto;
    align-self: flex-start;
  }
}
</style>
