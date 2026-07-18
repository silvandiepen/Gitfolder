<script setup lang="ts">
/**
 * @component LegalDoc
 * Shared reader layout for legal / policy pages (Privacy, Terms). Neutral shell.
 * Provide a title + last-updated string; put the sections in the default slot as
 * <section><h2>…</h2><p>…</p></section> blocks.
 */
defineProps<{
  title: string
  updated: string
}>()
</script>

<template>
  <div class="legal">
    <div class="legal__container">
      <h1 class="legal__title">{{ title }}</h1>
      <p class="legal__updated">Last updated: {{ updated }}</p>
      <div class="legal__body">
        <slot />
      </div>
    </div>
  </div>
</template>

<style lang="scss">
.legal {
  &__container {
    max-width: 760px;
    margin: 0 auto;
    padding: var(--space-xl) var(--space-l) var(--space-xxl);

    @include mobile { padding: var(--space-l) var(--space) var(--space-xl); }
  }

  &__title {
    font-size: var(--font-size-xxl);
    font-weight: var(--font-weight-bold);
    letter-spacing: -0.02em;
    margin-bottom: var(--space-s);
  }

  &__updated {
    font-size: var(--font-size-s);
    color: var(--color-subtle);
    margin-bottom: var(--space-xl);
  }

  &__body {
    section {
      margin-bottom: var(--space-l);
    }

    h2 {
      font-size: var(--font-size-l);
      font-weight: var(--font-weight-semibold);
      margin-bottom: var(--space-s);
    }

    p {
      font-size: var(--font-size);
      color: var(--color-muted);
      line-height: var(--line-height-relaxed);
      margin-bottom: var(--space-s);
    }

    ul {
      margin: 0 0 var(--space-s);
      padding-left: var(--space);
      list-style: disc;

      li {
        font-size: var(--font-size);
        color: var(--color-muted);
        line-height: var(--line-height-relaxed);
        margin-bottom: var(--space-xs);
      }
    }

    a {
      color: var(--accent-legible);
      text-decoration: underline;
      text-underline-offset: 2px;
    }
  }
}
</style>
