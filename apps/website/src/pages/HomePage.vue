<script setup lang="ts">
/**
 * @view HomePage
 * GitKit family landing page — introduces the umbrella and both apps.
 */
import MarketingLayout from '@/components/MarketingLayout.vue'
import AppCard from '@/components/AppCard.vue'
import FeatureGrid from '@/components/FeatureGrid.vue'
import type { Feature, AppCardContent } from '@/lib/content'
import GitFolderMark from '@/components/GitFolderMark.vue'
import GitKanbanMark from '@/components/GitKanbanMark.vue'
import { usePageMeta } from '@/lib/usePageMeta'
import { useContent } from '@/i18n'

interface HomeContent {
  meta: { title: string; description: string }
  hero: { eyebrow: string; title: string; subtitleHtml: string; ctaGitfolder: string; ctaGitkanban: string }
  apps: { title: string; subtitle: string; items: AppCardContent[] }
  principles: { title: string; subtitle: string; features: Feature[] }
  cta: { title: string; subtitle: string; primary: string; secondary: string }
}

const t = useContent<HomeContent>('home')

usePageMeta({ title: t.meta.title, description: t.meta.description })
</script>

<template>
  <MarketingLayout>
    <div class="mkt home">
      <!-- Hero -->
      <section class="mkt__hero">
        <div class="mkt__container mkt__hero-grid">
          <div class="mkt__hero-copy">
            <p class="mkt__eyebrow">{{ t.hero.eyebrow }}</p>
            <h1 class="mkt__hero-title">{{ t.hero.title }}</h1>
            <!-- eslint-disable-next-line vue/no-v-html -->
            <p class="mkt__hero-subtitle" v-html="t.hero.subtitleHtml"></p>
            <div class="mkt__hero-actions">
              <router-link to="/gitfolder" class="mkt__btn-pill home__btn--gf">{{ t.hero.ctaGitfolder }}</router-link>
              <router-link to="/gitkanban" class="mkt__btn-pill home__btn--gk">{{ t.hero.ctaGitkanban }}</router-link>
            </div>
          </div>

          <div class="home__hero-art" aria-hidden="true">
            <GitFolderMark class="home__hero-icon home__hero-icon--gf" :size="150" />
            <GitKanbanMark class="home__hero-icon home__hero-icon--gk" :size="150" />
          </div>
        </div>
      </section>

      <!-- Apps -->
      <section class="mkt__section home__apps">
        <div class="mkt__container">
          <div class="mkt__section-head">
            <h2 class="mkt__section-title">{{ t.apps.title }}</h2>
            <p class="mkt__section-subtitle">{{ t.apps.subtitle }}</p>
          </div>
          <div class="home__cards">
            <AppCard
              v-for="item in t.apps.items"
              :key="item.app"
              :app="item.app"
              :name="item.name"
              :tagline="item.tagline"
              :points="item.points"
              :to="item.to"
              :cta="item.cta"
              :badge="item.badge"
            />
          </div>
        </div>
      </section>

      <!-- Shared principles -->
      <section class="mkt__section home__principles">
        <div class="mkt__container">
          <div class="mkt__section-head">
            <h2 class="mkt__section-title">{{ t.principles.title }}</h2>
            <p class="mkt__section-subtitle">{{ t.principles.subtitle }}</p>
          </div>
          <FeatureGrid :features="t.principles.features" />
        </div>
      </section>

      <!-- CTA -->
      <section class="mkt__cta">
        <div class="mkt__container">
          <h2 class="mkt__cta-title">{{ t.cta.title }}</h2>
          <p class="mkt__cta-subtitle">{{ t.cta.subtitle }}</p>
          <div class="mkt__cta-actions">
            <router-link to="/gitfolder" class="mkt__btn-pill mkt__btn-pill--lg">{{ t.cta.primary }}</router-link>
            <router-link to="/gitkanban" class="mkt__btn-outline mkt__btn-outline--inverse">{{ t.cta.secondary }}</router-link>
          </div>
        </div>
      </section>
    </div>
  </MarketingLayout>
</template>

<style lang="scss">
.home {
  // Hero action buttons carry each app's colour explicitly.
  &__btn--gf {
    background: var(--gf-dark);
    &:hover { background: var(--gf-dark); }
  }
  &__btn--gk {
    background: var(--gk-dark);
    &:hover { background: var(--gk-dark); }
  }

  &__hero-art {
    display: flex;
    gap: var(--space-l);
    justify-content: center;
    align-items: center;

    @include mobile { gap: var(--space); }
  }

  &__hero-icon {
    box-shadow: var(--shadow-l);

    @include mobile {
      width: 112px;
      height: 112px;
    }
  }

  &__hero-icon--gf { transform: translateY(-14px) rotate(-4deg); }
  &__hero-icon--gk { transform: translateY(14px) rotate(4deg); }

  &__cards {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: var(--space-l);

    @include tablet { grid-template-columns: 1fr; }
  }
}
</style>
