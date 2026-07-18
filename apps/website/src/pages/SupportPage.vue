<script setup lang="ts">
/**
 * @view SupportPage
 * Support and troubleshooting info for the GitKit apps.
 */
import MarketingLayout from '@/components/MarketingLayout.vue'
import { usePageMeta } from '@/lib/usePageMeta'
import { useContent } from '@/i18n'

interface StepItem { title: string; descHtml: string }
interface SupportContent {
  meta: { title: string; description: string }
  title: string
  intro: string
  gitfolder: {
    heading: string
    setup: { title: string; steps: StepItem[] }
    common: { title: string; items: StepItem[] }
  }
  gitkanban: { heading: string; title: string; bodyHtml: string }
  stillStuck: { title: string; bodyHtml: string }
}

const t = useContent<SupportContent>('support')

usePageMeta({ title: t.meta.title, description: t.meta.description })
</script>

<template>
  <MarketingLayout>
    <div class="support">
      <div class="support__container">
        <h1 class="support__title">{{ t.title }}</h1>
        <p class="support__intro">{{ t.intro }}</p>

        <h2 class="support__app-heading" data-app="gitfolder">{{ t.gitfolder.heading }}</h2>

        <section class="support__section">
          <h2>{{ t.gitfolder.setup.title }}</h2>
          <div class="support__steps">
            <div v-for="(step, i) in t.gitfolder.setup.steps" :key="step.title" class="support__step">
              <span class="support__step-num">{{ i + 1 }}</span>
              <div>
                <h4>{{ step.title }}</h4>
                <!-- eslint-disable-next-line vue/no-v-html -->
                <p v-html="step.descHtml"></p>
              </div>
            </div>
          </div>
        </section>

        <section class="support__section">
          <h2>{{ t.gitfolder.common.title }}</h2>
          <div class="support__faq">
            <div v-for="item in t.gitfolder.common.items" :key="item.title" class="support__faq-item">
              <h4>{{ item.title }}</h4>
              <!-- eslint-disable-next-line vue/no-v-html -->
              <p v-html="item.descHtml"></p>
            </div>
          </div>
        </section>

        <h2 class="support__app-heading" data-app="gitkanban">{{ t.gitkanban.heading }}</h2>

        <section class="support__section">
          <h2>{{ t.gitkanban.title }}</h2>
          <!-- eslint-disable-next-line vue/no-v-html -->
          <p v-html="t.gitkanban.bodyHtml"></p>
        </section>

        <section class="support__section">
          <h2>{{ t.stillStuck.title }}</h2>
          <!-- eslint-disable-next-line vue/no-v-html -->
          <p v-html="t.stillStuck.bodyHtml"></p>
        </section>
      </div>
    </div>
  </MarketingLayout>
</template>

<style lang="scss">
.support {
  &__container {
    max-width: 720px;
    margin: 0 auto;
    padding: var(--space-xl) var(--space-l) var(--space-xxl);
  }

  @include e(title) {
    font-size: var(--font-size-xxl);
    font-weight: var(--font-weight-bold);
    margin-bottom: var(--space);
  }

  @include e(intro) {
    font-size: var(--font-size);
    color: var(--color-muted);
    line-height: var(--line-height-relaxed);
    margin-bottom: var(--space-xl);
  }

  @include e(app-heading) {
    display: inline-block;
    font-size: var(--font-size-m);
    font-weight: var(--font-weight-bold);
    letter-spacing: -0.01em;
    color: var(--accent-legible);
    padding: var(--space-xs) var(--space-s);
    border-radius: var(--radius-pill);
    background: var(--color-accent-tint);
    margin: var(--space) 0 var(--space-l);
  }

  a {
    color: var(--accent-legible);
    text-decoration: underline;
    text-underline-offset: 2px;
  }

  @include e(section) {
    margin-bottom: var(--space-xl);

    h2 {
      font-size: var(--font-size-l);
      font-weight: var(--font-weight-semibold);
      margin-bottom: var(--space);
      padding-bottom: var(--space-s);
      border-bottom: var(--border-width) solid var(--color-border-light);
    }

    p {
      font-size: var(--font-size-s);
      color: var(--color-muted);
      line-height: var(--line-height-relaxed);

      code {
        background: var(--surface-raised);
        padding: var(--space-xs) var(--space-xs);
        border-radius: var(--border-radius);
        font-family: var(--font-family-monospace);
        font-size: var(--font-size-xs);
      }
    }
  }

  @include e(steps) {
    display: flex;
    flex-direction: column;
    gap: var(--space);
  }

  @include e(step) {
    display: flex;
    gap: var(--space);
    align-items: flex-start;

    h4 {
      font-weight: var(--font-weight-semibold);
      margin-bottom: var(--space-xs);
    }

    p {
      font-size: var(--font-size-s);
      color: var(--color-muted);
      line-height: var(--line-height-relaxed);
    }
  }

  @include e(step-num) {
    flex-shrink: 0;
    width: 32px;
    height: 32px;
    border-radius: 50%;
    background: var(--color-accent-tint);
    color: var(--accent-legible);
    font-size: var(--font-size-s);
    font-weight: var(--font-weight-semibold);
    display: flex;
    align-items: center;
    justify-content: center;
  }

  @include e(faq) {
    display: flex;
    flex-direction: column;
    gap: var(--space-l);
  }

  @include e(faq-item) {
    h4 {
      font-size: var(--font-size);
      font-weight: var(--font-weight-semibold);
      margin-bottom: var(--space-s);
    }

    p {
      font-size: var(--font-size-s);
      color: var(--color-muted);
      line-height: var(--line-height-relaxed);
    }
  }
}
</style>
