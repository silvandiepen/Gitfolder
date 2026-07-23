<script setup lang="ts">
/**
 * GitKanban app icon derived from project-assets/GitKit/assets/icon.svg.
 * Colours are mapped through the website brand tokens in _variables.scss.
 */
withDefaults(
  defineProps<{
    size?: number | string
    title?: string
  }>(),
  {
    size: 24,
    title: 'GitKanban',
  },
)
</script>

<template>
  <svg
    class="gitkanban-mark"
    :width="size"
    :height="size"
    viewBox="0 0 153 153"
    role="img"
    :aria-label="title"
    xmlns="http://www.w3.org/2000/svg"
  >
    <g transform="translate(-207.5 -574)">
      <rect class="gitkanban-mark__background" x="207.5" y="574" width="153" height="153" />
      <path
        class="gitkanban-mark__ink"
        d="M251.5,610h28c4.97,0,9,4.03,9,9v63c0,9.93-8.07,18-18,18h-18c-4.97,0-9-4.03-9-9v-73c0-4.42,3.58-8,8-8Z"
      />
      <path
        class="gitkanban-mark__ink"
        d="M305.5,610h29c4.42,0,8,3.58,8,8v64c0,9.93-8.07,18-18,18h-18c-4.97,0-9-4.03-9-9v-73c0-4.42,3.58-8,8-8Z"
      />
      <rect class="gitkanban-mark__paper" x="234.5" y="601" width="45" height="90" rx="9" ry="9" />
      <rect class="gitkanban-mark__paper" x="288.5" y="601" width="45" height="90" rx="9" ry="9" />
      <rect class="gitkanban-mark__card" x="243.5" y="619" width="27" height="9" rx="4.5" ry="4.5" />
      <rect class="gitkanban-mark__card" x="243.5" y="637" width="27" height="9" rx="4.5" ry="4.5" />
      <rect class="gitkanban-mark__card" x="243.5" y="655" width="27" height="9" rx="4.5" ry="4.5" />
      <rect class="gitkanban-mark__card" x="297.5" y="619" width="27" height="9" rx="4.5" ry="4.5" />
      <rect class="gitkanban-mark__card" x="297.5" y="637" width="27" height="9" rx="4.5" ry="4.5" />
    </g>
  </svg>
</template>

<style lang="scss">
.gitkanban-mark {
  display: block;
  overflow: hidden;
  border-radius: 22%;

  &__background {
    fill: var(--gk);
  }

  &__ink {
    fill: var(--app-icon-ink);
  }

  &__paper {
    fill: var(--app-icon-paper);
  }

  &__card {
    fill: var(--app-icon-card);
  }
}
</style>
