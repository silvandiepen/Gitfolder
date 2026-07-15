<script setup lang="ts">
/**
 * @view HomePage
 * Landing page for GitFolder. Hero + features + CTA, matching Kod pattern.
 */
import GitFolderMark from '@/components/GitFolderMark.vue'
import MarketingLayout from '@/components/MarketingLayout.vue'
import { appStoreUrl } from '../links'

const features = [
  {
    icon: 'folder',
    title: 'Select your folders',
    desc: 'Pick any folder on your Mac. GitFolder watches it and creates snapshot commits when files change.',
  },
  {
    icon: 'github',
    title: 'Your GitHub, your repos',
    desc: 'Uses your existing GitHub SSH setup. Files go only to repositories you choose — nothing touches GitFolder servers.',
  },
  {
    icon: 'clock',
    title: 'Automatic intervals',
    desc: 'Set sync intervals per folder — 5, 15, 30, or 60 minutes. GitFolder works quietly in the background.',
  },
  {
    icon: 'shield',
    title: 'Local-first and private',
    desc: 'No GitFolder account needed. No cloud service. Your files move directly from your Mac to your GitHub repos.',
  },
  {
    icon: 'terminal',
    title: 'Uses your Git setup',
    desc: 'Leverages the Git and SSH configuration you already have. No bundled Git, no separate keys unless you want them.',
  },
  {
    icon: 'menu',
    title: 'Menu bar app',
    desc: 'Lives in the macOS menu bar. Check sync status, pause syncing, or trigger a manual sync — all from the menu.',
  },
]
</script>

<template>
  <MarketingLayout>
    <div class="landing">
      <!-- Hero -->
      <section class="landing__hero">
        <div class="landing__container landing__hero-content">
          <div class="landing__hero-copy">
            <p class="landing__eyebrow">macOS menu bar utility</p>
            <h1 class="landing__hero-title">Automatic version history for your folders.</h1>
            <p class="landing__hero-subtitle">
              GitFolder watches selected folders on your Mac and creates quiet GitHub snapshot commits when files change. No cloud service. No account. Just local-first versioning.
            </p>
            <div class="landing__hero-actions">
              <a :href="appStoreUrl" class="landing__btn-pill" target="_blank" rel="noopener">
                Download on the Mac App Store
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
              </a>
              <router-link to="/docs" class="landing__btn-outline">Read the docs</router-link>
            </div>
          </div>

          <div class="landing__hero-art" aria-hidden="true">
            <GitFolderMark class="landing__hero-mark" :size="224" title="GitFolder line artwork" />
            <div class="landing__hero-line landing__hero-line--top" />
            <div class="landing__hero-line landing__hero-line--middle" />
            <div class="landing__hero-line landing__hero-line--bottom" />
          </div>
        </div>
      </section>

      <!-- Features -->
      <section class="landing__features">
        <div class="landing__container">
          <h2 class="landing__section-title">Simple app, simple setup</h2>
          <p class="landing__section-subtitle">
            Pick a folder, connect a GitHub repo, choose an interval. That's it.
          </p>
          <div class="landing__grid">
            <div v-for="f in features" :key="f.title" class="landing__card">
              <div class="landing__card-icon">
                <svg v-if="f.icon === 'folder'" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/></svg>
                <svg v-else-if="f.icon === 'github'" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 19c-5 1.5-5-2.5-7-3m14 6v-3.87a3.37 3.37 0 0 0-.94-2.61c3.14-.35 6.44-1.54 6.44-7A5.44 5.44 0 0 0 20 4.77 5.07 5.07 0 0 0 19.91 1S18.73.65 16 2.48a13.38 13.38 0 0 0-7 0C6.27.65 5.09 1 5.09 1A5.07 5.07 0 0 0 5 4.77a5.44 5.44 0 0 0-1.5 3.78c0 5.42 3.3 6.61 6.44 7A3.37 3.37 0 0 0 9 18.13V22"/></svg>
                <svg v-else-if="f.icon === 'clock'" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
                <svg v-else-if="f.icon === 'shield'" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
                <svg v-else-if="f.icon === 'terminal'" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="4 17 10 11 4 5"/><line x1="12" y1="19" x2="20" y2="19"/></svg>
                <svg v-else width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="3" y1="12" x2="21" y2="12"/><line x1="3" y1="6" x2="21" y2="6"/><line x1="3" y1="18" x2="21" y2="18"/></svg>
              </div>
              <h3 class="landing__card-title">{{ f.title }}</h3>
              <p class="landing__card-desc">{{ f.desc }}</p>
            </div>
          </div>
        </div>
      </section>

      <!-- CTA -->
      <section class="landing__cta">
        <div class="landing__container">
          <h2 class="landing__cta-title">Version your folders, quietly.</h2>
          <p class="landing__cta-subtitle">A small macOS app that does one thing well.</p>
          <div class="landing__cta-actions">
            <a :href="appStoreUrl" class="landing__btn-pill landing__btn-pill--lg" target="_blank" rel="noopener">
              Download on the Mac App Store
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
            </a>
            <router-link to="/docs" class="landing__btn-outline landing__btn-outline--inverse">Read the docs</router-link>
          </div>
        </div>
      </section>
    </div>
  </MarketingLayout>
</template>

<style lang="scss">
.landing {
  &__container {
    max-width: 1120px;
    margin: 0 auto;
    padding: 0 32px;
  }

  // ── Buttons ──────────────────────────────────────────────────────────
  @include e(btn-pill) {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    font-weight: var(--font-weight-semibold);
    color: var(--color-text-inverse);
    background: var(--color-accent);
    padding: 10px 22px;
    border-radius: 999px;
    font-size: var(--font-size-sm);
    transition: all var(--transition-fast);
    text-decoration: none;

    &:hover {
      background: var(--color-accent-dark);
      transform: translateY(-1px);
      color: var(--color-text-inverse);
    }

    @include m(lg) {
      font-size: var(--font-size-base);
      padding: 14px 28px;
    }
  }

  @include e(btn-outline) {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    font-weight: var(--font-weight-medium);
    color: var(--color-text-secondary);
    background: transparent;
    border: 1px solid var(--color-border);
    padding: 9px 18px;
    border-radius: 999px;
    font-size: var(--font-size-sm);
    transition: all var(--transition-fast);
    text-decoration: none;

    &:hover {
      border-color: var(--color-accent);
      color: var(--color-text-primary);
    }

    @include m(inverse) {
      border-color: rgba(255, 255, 255, 0.38);
      color: var(--color-text-inverse);

      &:hover {
        border-color: var(--color-white);
        color: var(--color-text-inverse);
      }
    }
  }

  // ── Hero ─────────────────────────────────────────────────────────────
  @include e(hero) {
    padding: 80px 0 64px;
  }

  @include e(hero-content) {
    display: grid;
    grid-template-columns: minmax(0, 1.1fr) minmax(260px, 0.9fr);
    gap: 48px;
    align-items: center;

    @include tablet {
      grid-template-columns: 1fr;
      gap: 36px;
    }
  }

  @include e(hero-copy) {
    max-width: 640px;
  }

  @include e(hero-art) {
    position: relative;
    min-height: 300px;
    display: grid;
    place-items: center;
    color: var(--color-accent);

    &::before {
      content: '';
      position: absolute;
      inset: 24px;
      border-radius: 32px;
      background:
        radial-gradient(circle at 28% 22%, color-mix(in srgb, var(--color-accent) 18%, transparent), transparent 34%),
        linear-gradient(135deg, color-mix(in srgb, var(--color-accent) 14%, var(--color-surface)), var(--color-surface));
      border: 1px solid var(--color-border-light);
      box-shadow: var(--shadow-lg);
    }
  }

  @include e(hero-mark) {
    position: relative;
    z-index: 1;
    color: var(--color-text-primary);
    opacity: 0.88;
    filter: drop-shadow(0 16px 32px rgba(0, 0, 0, 0.16));
  }

  @include e(hero-line) {
    position: absolute;
    z-index: 0;
    height: 2px;
    border-radius: 999px;
    background: currentColor;
    opacity: 0.16;

    @include m(top) {
      width: 58%;
      top: 78px;
      right: 0;
    }

    @include m(middle) {
      width: 72%;
      left: 12px;
      top: 50%;
    }

    @include m(bottom) {
      width: 52%;
      right: 36px;
      bottom: 72px;
    }
  }

  @include e(eyebrow) {
    font-size: var(--font-size-sm);
    font-weight: var(--font-weight-semibold);
    color: var(--color-accent);
    margin-bottom: 12px;
  }

  @include e(hero-title) {
    font-size: 32px;
    font-weight: var(--font-weight-bold);
    line-height: 1.2;
    letter-spacing: -0.02em;
    margin-bottom: 16px;
  }

  @include e(hero-subtitle) {
    font-size: var(--font-size-base);
    color: var(--color-text-secondary);
    line-height: var(--line-height-relaxed);
    margin-bottom: 24px;
  }

  @include e(hero-actions) {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
  }

  // ── Features ─────────────────────────────────────────────────────────
  @include e(features) {
    padding: 64px 0;
  }

  @include e(section-title) {
    font-size: var(--font-size-xl);
    font-weight: var(--font-weight-bold);
    margin-bottom: 12px;
    letter-spacing: -0.01em;
  }

  @include e(section-subtitle) {
    font-size: var(--font-size-base);
    color: var(--color-text-secondary);
    max-width: 460px;
    margin-bottom: 48px;
    line-height: var(--line-height-relaxed);
  }

  @include e(grid) {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 20px;

    @include tablet { grid-template-columns: repeat(2, 1fr); }
    @include mobile { grid-template-columns: 1fr; }
  }

  @include e(card) {
    background: var(--color-surface);
    border-radius: 16px;
    border: 1px solid var(--color-border-light);
    padding: 24px;
  }

  @include e(card-icon) {
    width: 44px;
    height: 44px;
    border-radius: 12px;
    background: color-mix(in srgb, var(--color-accent) 10%, var(--color-surface));
    display: flex;
    align-items: center;
    justify-content: center;
    margin-bottom: 16px;
    color: var(--color-accent);
  }

  @include e(card-title) {
    font-size: var(--font-size-base);
    font-weight: var(--font-weight-semibold);
    margin-bottom: 6px;
  }

  @include e(card-desc) {
    font-size: var(--font-size-sm);
    color: var(--color-text-secondary);
    line-height: var(--line-height-relaxed);
  }

  // ── CTA ──────────────────────────────────────────────────────────────
  @include e(cta) {
    padding: 64px 0;
    background: var(--color-primary);
    color: var(--color-text-inverse);
  }

  @include e(cta-title) {
    font-size: var(--font-size-xl);
    font-weight: var(--font-weight-bold);
    margin-bottom: 8px;
    letter-spacing: -0.01em;
    color: var(--color-text-inverse);
  }

  @include e(cta-subtitle) {
    font-size: var(--font-size-base);
    opacity: 0.85;
    margin-bottom: 24px;
    color: var(--color-text-inverse);
  }

  @include e(cta-actions) {
    display: flex;
    align-items: center;
    gap: 12px;
    flex-wrap: wrap;

    .landing__btn-pill {
      background: var(--color-white);
      color: var(--color-primary);

      &:hover {
        background: var(--color-white);
        opacity: 0.9;
        color: var(--color-primary);
      }
    }
  }
}
</style>
