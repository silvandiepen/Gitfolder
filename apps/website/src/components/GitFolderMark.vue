<script setup lang="ts">
/**
 * GitFolder supplied line-mark SVG from project-assets/Gitfolder/logo-gitfolder.svg.
 * Uses currentColor so the mark can work as brand art, UI ornament, and template-style icon.
 */
withDefaults(
  defineProps<{
    size?: number | string
    title?: string
  }>(),
  {
    size: 24,
    title: 'GitFolder',
  },
)
</script>

<template>
  <svg
    class="gitfolder-mark"
    :width="size"
    :height="size"
    viewBox="0 0 144 144"
    fill="none"
    role="img"
    :aria-label="title"
    xmlns="http://www.w3.org/2000/svg"
  >
    <path
      class="gitfolder-mark__line"
      d="M111.38 4.5H32.62C17.09 4.5 4.5 17.09 4.5 32.62v78.75c0 15.53 12.59 28.12 28.12 28.12h78.75c15.53 0 28.12-12.59 28.12-28.12V32.62C139.5 17.09 126.91 4.5 111.38 4.5z"
    />
    <path
      class="gitfolder-mark__line"
      d="M4.5 42.47h62.84c2.98 0 5.85-1.19 7.95-3.3l6.07-6.07c2.11-2.11 4.97-3.3 7.95-3.3h24.43c2.98 0 5.85 1.19 7.95 3.3l6.07 6.07c2.11 2.11 4.97 3.3 7.95 3.3h3.78"
    />
    <path
      class="gitfolder-mark__line"
      d="M139.5 72H76.66c-2.98 0-5.85-1.19-7.95-3.3l-6.07-6.07c-2.11-2.11-4.97-3.3-7.95-3.3H30.25c-2.98 0-5.85 1.19-7.95 3.3l-6.07 6.07c-2.11 2.11-4.97 3.3-7.95 3.3H4.5"
    />
    <path
      class="gitfolder-mark__line"
      d="M4.5 101.53h62.84c2.98 0 5.85-1.19 7.95-3.3l6.07-6.07c2.11-2.11 4.97-3.3 7.95-3.3h24.43c2.98 0 5.85 1.19 7.95 3.3l6.07 6.07c2.11 2.11 4.97 3.3 7.95 3.3h3.78"
    />
  </svg>
</template>

<style lang="scss">
.gitfolder-mark {
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
