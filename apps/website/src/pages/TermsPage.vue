<script setup lang="ts">
/**
 * @view TermsPage
 * Terms & Conditions for the GitKit apps. Body prose lives in
 * i18n/pages/<locale>/terms.md and is rendered with nizel.
 */
import MarketingLayout from '@/components/MarketingLayout.vue'
import LegalDoc from '@/components/LegalDoc.vue'
import { usePageMeta } from '@/lib/usePageMeta'
import { useMarkdown } from '@/lib/useMarkdown'
import { usePageMarkdown } from '@/i18n'

usePageMeta({
  title: 'Terms & Conditions — GitKit',
  description:
    'The terms of use for the GitKit apps, GitFolder and GitKanban — provided as-is, using your own git repositories and accounts.',
})

const body = useMarkdown(() => usePageMarkdown('terms'))
</script>

<template>
  <MarketingLayout>
    <LegalDoc title="Terms &amp; Conditions" updated="July 2026">
      <!-- eslint-disable-next-line vue/no-v-html -->
      <div v-html="body"></div>
    </LegalDoc>
  </MarketingLayout>
</template>
