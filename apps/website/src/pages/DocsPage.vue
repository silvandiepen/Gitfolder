<script setup lang="ts">
/**
 * @view DocsPage
 * Documentation page with sidebar navigation, matching Kod's DocsView pattern.
 * All copy is loaded from `i18n/locales/<locale>/docs.json` so it can be translated.
 */
import { ref } from 'vue'
import MarketingLayout from '@/components/MarketingLayout.vue'
import { usePageMeta } from '@/lib/usePageMeta'
import { useContent } from '@/i18n'

interface StepItem {
  title: string
  html: string
}

interface SpecItem {
  term: string
  html: string
}

interface FaqItem {
  q: string
  html: string
}

interface StepsBlock {
  type: 'steps'
  items: StepItem[]
}

interface ProseBlock {
  type: 'prose'
  html: string
}

interface ListBlock {
  type: 'list'
  items: string[]
}

interface CalloutBlock {
  type: 'callout'
  variant: 'info' | 'warning'
  icon: string
  title: string
  html: string
}

interface SpecsBlock {
  type: 'specs'
  items: SpecItem[]
}

interface FaqBlock {
  type: 'faq'
  items: FaqItem[]
}

type DocsBlock =
  | StepsBlock
  | ProseBlock
  | ListBlock
  | CalloutBlock
  | SpecsBlock
  | FaqBlock

interface DocsSection {
  id: string
  label: string
  title: string
  blocks: DocsBlock[]
}

interface DocsContent {
  meta: { title: string; description: string }
  sidebarTitle: string
  sidebarNoteHtml: string
  sections: DocsSection[]
}

const t = useContent<DocsContent>('docs')

usePageMeta({
  title: t.meta.title,
  description: t.meta.description,
})

const sections = t.sections.map((s) => ({ id: s.id, label: s.label }))

const activeSection = ref(sections[0]?.id ?? '')

function scrollTo(id: string) {
  activeSection.value = id
  document.getElementById(id)?.scrollIntoView({ behavior: 'smooth', block: 'start' })
}
</script>

<template>
  <MarketingLayout>
    <div class="docs" data-app="gitfolder">
      <div class="docs__container">
        <div class="docs__layout">
          <!-- Sidebar -->
          <aside class="docs__sidebar">
            <h3 class="docs__sidebar-title">{{ t.sidebarTitle }}</h3>
            <!-- eslint-disable-next-line vue/no-v-html -->
            <p class="docs__sidebar-note" v-html="t.sidebarNoteHtml" />
            <nav class="docs__sidebar-nav">
              <button
                v-for="s in sections"
                :key="s.id"
                class="docs__sidebar-link"
                :class="{ 'docs__sidebar-link--active': activeSection === s.id }"
                @click="scrollTo(s.id)"
              >
                {{ s.label }}
              </button>
            </nav>
          </aside>

          <!-- Content -->
          <div class="docs__content">
            <section
              v-for="section in t.sections"
              :id="section.id"
              :key="section.id"
              class="docs__section"
            >
              <h2 class="docs__section-title">{{ section.title }}</h2>

              <template v-for="(block, i) in section.blocks" :key="i">
                <!-- Steps -->
                <div v-if="block.type === 'steps'" class="docs__steps">
                  <div v-for="(step, si) in block.items" :key="si" class="docs__step">
                    <span class="docs__step-num">{{ si + 1 }}</span>
                    <div>
                      <h4>{{ step.title }}</h4>
                      <!-- eslint-disable-next-line vue/no-v-html -->
                      <p v-html="step.html" />
                    </div>
                  </div>
                </div>

                <!-- Prose -->
                <!-- eslint-disable-next-line vue/no-v-html -->
                <p v-else-if="block.type === 'prose'" v-html="block.html" />

                <!-- List -->
                <ul v-else-if="block.type === 'list'" class="docs__list">
                  <!-- eslint-disable-next-line vue/no-v-html -->
                  <li v-for="(item, li) in block.items" :key="li" v-html="item" />
                </ul>

                <!-- Specs -->
                <div v-else-if="block.type === 'specs'" class="docs__specs">
                  <div v-for="(spec, spi) in block.items" :key="spi" class="docs__spec">
                    <span class="docs__spec-label">{{ spec.term }}</span>
                    <!-- eslint-disable-next-line vue/no-v-html -->
                    <span class="docs__spec-value" v-html="spec.html" />
                  </div>
                </div>

                <!-- Callout -->
                <div
                  v-else-if="block.type === 'callout'"
                  class="docs__callout"
                  :class="`docs__callout--${block.variant}`"
                >
                  <div class="docs__callout-icon">{{ block.icon }}</div>
                  <div>
                    <h4>{{ block.title }}</h4>
                    <!-- eslint-disable-next-line vue/no-v-html -->
                    <div v-html="block.html" />
                  </div>
                </div>

                <!-- FAQ -->
                <div v-else-if="block.type === 'faq'" class="docs__faq">
                  <div v-for="(item, fi) in block.items" :key="fi" class="docs__faq-item">
                    <h4>{{ item.q }}</h4>
                    <!-- eslint-disable-next-line vue/no-v-html -->
                    <p v-html="item.html" />
                  </div>
                </div>
              </template>
            </section>
          </div>
        </div>
      </div>
    </div>
  </MarketingLayout>
</template>

<style lang="scss">
.docs {
  &__container {
    max-width: 1120px;
    margin: 0 auto;
    padding: 0 var(--space-l);
  }

  @include e(layout) {
    display: grid;
    grid-template-columns: 220px 1fr;
    gap: var(--space-xl);
    padding-top: var(--space-xl);
    padding-bottom: var(--space-xxl);

    @include tablet {
      grid-template-columns: 1fr;
    }
  }

  // Sidebar
  @include e(sidebar) {
    position: sticky;
    top: 100px;
    align-self: start;

    @include tablet { display: none; }
  }

  @include e(sidebar-title) {
    font-size: var(--font-size-xs);
    font-weight: var(--font-weight-semibold);
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--color-subtle);
    margin-bottom: var(--space-s);
  }

  @include e(sidebar-note) {
    font-size: var(--font-size-xs);
    color: var(--color-subtle);
    line-height: var(--line-height-relaxed);
    margin-bottom: var(--space);

    a {
      color: var(--accent-legible);
      text-decoration: underline;
      text-underline-offset: 2px;
    }
  }

  @include e(sidebar-nav) {
    display: flex;
    flex-direction: column;
    gap: var(--space-xs);
  }

  @include e(sidebar-link) {
    display: block;
    text-align: left;
    font-size: var(--font-size-s);
    font-weight: var(--font-weight-medium);
    color: var(--color-muted);
    padding: var(--space-s) var(--space-s);
    border-radius: var(--border-radius-l);
    transition: all var(--transition-fast);
    background: transparent;
    cursor: pointer;

    &:hover {
      color: var(--color-foreground);
      background: var(--surface-raised);
    }

    @include m(active) {
      color: var(--accent-legible);
      background: var(--color-accent-tint);
    }
  }

  // Content
  @include e(content) {
    min-width: 0;
  }

  @include e(section) {
    padding-top: var(--space-xl);
    &:first-child { padding-top: 0; }
  }

  @include e(section-title) {
    font-size: var(--font-size-xl);
    font-weight: var(--font-weight-bold);
    margin-bottom: var(--space-l);
    padding-bottom: var(--space-s);
    border-bottom: var(--border-width) solid var(--color-border-light);
  }

  p {
    font-size: var(--font-size-s);
    color: var(--color-muted);
    line-height: var(--line-height-relaxed);
    margin-bottom: var(--space);

    code {
      background: var(--surface-raised);
      padding: var(--space-xs) var(--space-xs);
      border-radius: var(--border-radius);
      font-family: var(--font-family-monospace);
      font-size: var(--font-size-xs);
    }
  }

  // Steps
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

  // Lists
  @include e(list) {
    padding-left: var(--space);
    display: flex;
    flex-direction: column;
    gap: var(--space-s);

    li {
      font-size: var(--font-size-s);
      color: var(--color-muted);
      line-height: var(--line-height-relaxed);
      list-style: disc;

      code {
        background: var(--surface-raised);
        padding: var(--space-xs) var(--space-xs);
        border-radius: var(--border-radius);
        font-family: var(--font-family-monospace);
        font-size: var(--font-size-xs);
      }
    }
  }

  // Callouts
  @include e(callout) {
    display: flex;
    gap: var(--space);
    padding: var(--space) var(--space-l);
    border-radius: var(--border-radius-xxl);
    margin-top: var(--space-l);

    @include m(warning) {
      background: #fef3cd;
      border: var(--border-width) solid color-mix(in srgb, #ffc92c, transparent 60%);
    }

    @include m(info) {
      background: var(--color-accent-tint);
      border: var(--border-width) solid color-mix(in srgb, var(--color-accent), transparent 60%);
    }

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

  @include e(callout-icon) {
    font-size: var(--font-size-l);
    flex-shrink: 0;
    margin-top: var(--space-xs);
  }

  // Specs table
  @include e(specs) {
    display: flex;
    flex-direction: column;
    gap: 1px;
    background: var(--color-border-light);
    border-radius: var(--border-radius-xxl);
    overflow: hidden;
    margin-bottom: var(--space-l);
  }

  @include e(spec) {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: var(--space-s) var(--space);
    background: var(--surface);

    code {
      background: var(--surface-raised);
      padding: var(--space-xs) var(--space-xs);
      border-radius: var(--border-radius);
      font-family: var(--font-family-monospace);
      font-size: var(--font-size-xs);
    }
  }

  @include e(spec-label) {
    font-size: var(--font-size-s);
    font-weight: var(--font-weight-semibold);
  }

  @include e(spec-value) {
    font-size: var(--font-size-s);
    color: var(--color-muted);
  }

  // FAQ
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
