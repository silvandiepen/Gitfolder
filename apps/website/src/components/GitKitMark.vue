<script setup lang="ts">
/**
 * GitKit umbrella mark — the neutral family logo. Same rounded-square line family
 * as the app marks; the interior is a small git commit graph (a branch off a
 * trunk) to signal "the shared git engine behind the apps".
 */
withDefaults(
  defineProps<{
    size?: number | string
    title?: string
  }>(),
  {
    size: 24,
    title: 'GitKit',
  },
)
</script>

<template>
  <svg
    class="gitkit-mark"
    :width="size"
    :height="size"
    viewBox="0 0 144 144"
    fill="none"
    role="img"
    :aria-label="title"
    xmlns="http://www.w3.org/2000/svg"
  >
    <!-- Rounded-square container (shared with the app marks) -->
    <path
      class="gitkit-mark__line"
      d="M111.38 4.5H32.62C17.09 4.5 4.5 17.09 4.5 32.62v78.75c0 15.53 12.59 28.12 28.12 28.12h78.75c15.53 0 28.12-12.59 28.12-28.12V32.62C139.5 17.09 126.91 4.5 111.38 4.5z"
    />
    <!-- Trunk -->
    <path class="gitkit-mark__line" d="M56 44V100" />
    <!-- Branch off the trunk -->
    <path class="gitkit-mark__line" d="M56 72H83" />
    <!-- Commit nodes -->
    <circle class="gitkit-mark__node" cx="56" cy="44" r="8" />
    <circle class="gitkit-mark__node" cx="56" cy="100" r="8" />
    <circle class="gitkit-mark__node" cx="94" cy="72" r="8" />
  </svg>
</template>

<style lang="scss">
.gitkit-mark {
  display: block;
  overflow: visible;

  &__line,
  &__node {
    stroke: currentColor;
    stroke-width: 9;
    stroke-linecap: round;
    stroke-linejoin: round;
    stroke-miterlimit: 10;
  }

  &__node {
    fill: none;
  }
}
</style>
