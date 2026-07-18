<script setup lang="ts">
/**
 * GitKanban line-mark — same rounded-square line family as GitFolderMark, but the
 * interior reads as a kanban board: three columns with staggered cards.
 * Uses currentColor so it works as brand art, UI ornament, and template icon.
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
    viewBox="0 0 144 144"
    fill="none"
    role="img"
    :aria-label="title"
    xmlns="http://www.w3.org/2000/svg"
  >
    <!-- Rounded-square container (shared with the GitFolder mark) -->
    <path
      class="gitkanban-mark__line"
      d="M111.38 4.5H32.62C17.09 4.5 4.5 17.09 4.5 32.62v78.75c0 15.53 12.59 28.12 28.12 28.12h78.75c15.53 0 28.12-12.59 28.12-28.12V32.62C139.5 17.09 126.91 4.5 111.38 4.5z"
    />
    <!-- Column dividers -->
    <path class="gitkanban-mark__line" d="M51.5 34V110" />
    <path class="gitkanban-mark__line" d="M92.5 34V110" />
    <!-- Staggered cards, one per column -->
    <path class="gitkanban-mark__line" d="M18 50H40" />
    <path class="gitkanban-mark__line" d="M60 62H84" />
    <path class="gitkanban-mark__line" d="M104 44H126" />
  </svg>
</template>

<style lang="scss">
.gitkanban-mark {
  display: block;
  overflow: visible;

  &__line {
    stroke: currentColor;
    stroke-width: 9;
    stroke-linecap: round;
    stroke-linejoin: round;
    stroke-miterlimit: 10;
  }
}
</style>
