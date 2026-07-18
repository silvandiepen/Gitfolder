<script setup lang="ts">
/**
 * @view GitFolderPage
 * GitFolder product page — shipped app. Themed turquoise via data-app="gitfolder".
 */
import MarketingLayout from '@/components/MarketingLayout.vue'
import FeatureGrid from '@/components/FeatureGrid.vue'
import type { Feature, Step } from '@/lib/content'
import GitFolderMark from '@/components/GitFolderMark.vue'
import { usePageMeta } from '@/lib/usePageMeta'
import { appStoreUrl } from '@/links'
import { useContent } from '@/i18n'

interface GitFolderContent {
  meta: { title: string; description: string }
  hero: { eyebrow: string; title: string; subtitle: string; download: string; docs: string }
  steps: { title: string; subtitle: string; items: Step[] }
  features: { title: string; subtitle: string; items: Feature[] }
  cta: { title: string; subtitle: string; download: string; docs: string }
}

const t = useContent<GitFolderContent>('gitfolder')

usePageMeta({ title: t.meta.title, description: t.meta.description })
</script>

<template>
  <MarketingLayout>
    <div class="mkt product" data-app="gitfolder">
      <!-- Hero -->
      <section class="mkt__hero">
        <div class="mkt__container mkt__hero-grid">
          <div class="mkt__hero-copy">
            <p class="mkt__eyebrow">{{ t.hero.eyebrow }}</p>
            <h1 class="mkt__hero-title">{{ t.hero.title }}</h1>
            <p class="mkt__hero-subtitle">{{ t.hero.subtitle }}</p>
            <div class="mkt__hero-actions">
              <a :href="appStoreUrl" class="mkt__btn-pill" target="_blank" rel="noopener">
                {{ t.hero.download }}
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
              </a>
              <router-link to="/docs" class="mkt__btn-outline">{{ t.hero.docs }}</router-link>
            </div>
          </div>
          <div class="mkt__hero-art">
            <GitFolderMark class="mkt__hero-mark" :size="200" title="GitFolder" />
          </div>
        </div>
      </section>

      <!-- How it works -->
      <section class="mkt__section product__steps-section">
        <div class="mkt__container">
          <div class="mkt__section-head">
            <h2 class="mkt__section-title">{{ t.steps.title }}</h2>
            <p class="mkt__section-subtitle">{{ t.steps.subtitle }}</p>
          </div>
          <ol class="product__steps" role="list">
            <li v-for="s in t.steps.items" :key="s.n" class="product__step">
              <span class="product__step-num" aria-hidden="true">{{ s.n }}</span>
              <div>
                <h3 class="product__step-title">{{ s.title }}</h3>
                <p class="product__step-desc">{{ s.desc }}</p>
              </div>
            </li>
          </ol>
        </div>
      </section>

      <!-- Features -->
      <section class="mkt__section product__features">
        <div class="mkt__container">
          <div class="mkt__section-head">
            <h2 class="mkt__section-title">{{ t.features.title }}</h2>
            <p class="mkt__section-subtitle">{{ t.features.subtitle }}</p>
          </div>
          <FeatureGrid :features="t.features.items" />
        </div>
      </section>

      <!-- CTA -->
      <section class="mkt__cta">
        <div class="mkt__container">
          <h2 class="mkt__cta-title">{{ t.cta.title }}</h2>
          <p class="mkt__cta-subtitle">{{ t.cta.subtitle }}</p>
          <div class="mkt__cta-actions">
            <a :href="appStoreUrl" class="mkt__btn-pill mkt__btn-pill--lg" target="_blank" rel="noopener">
              {{ t.cta.download }}
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
            </a>
            <router-link to="/docs" class="mkt__btn-outline mkt__btn-outline--inverse">{{ t.cta.docs }}</router-link>
          </div>
        </div>
      </section>
    </div>
  </MarketingLayout>
</template>

<style lang="scss">
.product {
  &__steps {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: var(--space-l);
    padding: 0;
    margin: 0;

    @include tablet { grid-template-columns: 1fr; }
  }

  &__step {
    display: flex;
    gap: var(--space);
    align-items: flex-start;
  }

  &__step-num {
    flex: 0 0 auto;
    display: grid;
    place-items: center;
    width: 40px;
    height: 40px;
    border-radius: var(--radius-pill);
    background: var(--color-accent-tint);
    color: var(--accent-legible);
    font-weight: var(--font-weight-bold);
  }

  &__step-title {
    font-size: var(--font-size-m);
    font-weight: var(--font-weight-semibold);
    margin-bottom: var(--space-xs);
  }

  &__step-desc {
    font-size: var(--font-size-s);
    color: var(--color-muted);
    line-height: var(--line-height-relaxed);
  }
}
</style>
