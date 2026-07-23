<script setup lang="ts">
/**
 * GitFolder app icon derived from project-assets/GitKit/assets/icon.svg.
 * Colours are mapped through the website brand tokens in _variables.scss.
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
    viewBox="0 0 153 153"
    role="img"
    :aria-label="title"
    xmlns="http://www.w3.org/2000/svg"
  >
    <g transform="translate(-18.5 -574)">
      <rect class="gitfolder-mark__background" x="18.5" y="574" width="153" height="153" />
      <path
        class="gitfolder-mark__ink"
        d="M72.5,619h12.44c3.41,0,6.53,1.93,8.05,4.98l4.02,8.05c1.52,3.05,4.64,4.98,8.05,4.98h30.44c4.97,0,9,4.03,9,9v36c0,9.94-8.06,18-18,18h-54c-4.97,0-9-4.03-9-9v-63c0-4.97,4.03-9,9-9Z"
      />
      <path
        class="gitfolder-mark__paper"
        d="M63.5,610h12.44c3.41,0,6.53,1.93,8.05,4.98l6.51,13.02h36c4.97,0,9,4.03,9,9v45c0,4.97-4.03,9-9,9h-63c-4.97,0-9-4.03-9-9v-63c0-4.97,4.03-9,9-9Z"
      />
      <path
        class="gitfolder-mark__highlight"
        d="M83.71,614.42c-1.36-2.71-4.13-4.42-7.16-4.42h-14.06c-4.42,0-8,3.58-8,8v10h36l-6.79-13.58Z"
      />
    </g>
  </svg>
</template>

<style lang="scss">
.gitfolder-mark {
  display: block;
  overflow: hidden;
  border-radius: 22%;

  &__background {
    fill: var(--gf);
  }

  &__ink {
    fill: var(--app-icon-ink);
  }

  &__paper {
    fill: var(--app-icon-paper);
  }

  &__highlight {
    fill: var(--gf-icon-highlight);
  }
}
</style>
