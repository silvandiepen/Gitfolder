<script setup lang="ts">
/**
 * @view PrivacyPage
 * Privacy policy for GitFolder.
 */
import MarketingLayout from '@/components/MarketingLayout.vue'
</script>

<template>
  <MarketingLayout>
    <div class="privacy">
      <div class="privacy__container">
        <h1 class="privacy__title">Privacy</h1>
        <p class="privacy__updated">Last updated: June 2026</p>

        <section class="privacy__section">
          <h2>No cloud service</h2>
          <p>GitFolder does not run a cloud sync service. The app reads folders you explicitly select and pushes changes directly to GitHub repositories you configure.</p>
        </section>

        <section class="privacy__section">
          <h2>No GitFolder account</h2>
          <p>There is no GitFolder account. No email, no password, no user profile. The app is a local macOS utility that talks directly to GitHub.</p>
        </section>

        <section class="privacy__section">
          <h2>No data collection</h2>
          <p>GitFolder does not collect, transmit, or store any personal data on GitFolder servers. File contents move directly from your Mac to your GitHub repositories.</p>
        </section>

        <section class="privacy__section">
          <h2>Local data</h2>
          <p>Configuration (folder paths, repository URLs, sync intervals) is stored locally on your Mac. GitHub tokens are stored in macOS Keychain, not in GitFolder's config file. GitFolder does not phone home with telemetry, analytics, or usage data.</p>
        </section>

        <section class="privacy__section">
          <h2>GitHub data</h2>
          <p>Your selected folder contents are transmitted directly from your Mac to the GitHub repositories you configure so GitFolder can create and push snapshot commits. Your files are stored under your GitHub account and subject to GitHub's privacy policy.</p>
        </section>

        <section class="privacy__section">
          <h2>Contact</h2>
          <p>Questions about privacy? Open an issue on <a href="https://github.com/silvandiepen/Gitfolder" target="_blank" rel="noopener">GitHub</a>.</p>
        </section>
      </div>
    </div>
  </MarketingLayout>
</template>

<style lang="scss" scoped>
.privacy {
  &__container {
    max-width: 720px;
    margin: 0 auto;
    padding: 48px 32px 96px;
  }

  @include e(title) {
    font-size: var(--font-size-xxl);
    font-weight: var(--font-weight-bold);
    margin-bottom: 8px;
  }

  @include e(updated) {
    font-size: var(--font-size-sm);
    color: var(--color-text-tertiary);
    margin-bottom: 48px;
  }

  @include e(section) {
    margin-bottom: 32px;

    h2 {
      font-size: var(--font-size-lg);
      font-weight: var(--font-weight-semibold);
      margin-bottom: 12px;
    }

    p {
      font-size: var(--font-size-sm);
      color: var(--color-text-secondary);
      line-height: var(--line-height-relaxed);
    }
  }
}
</style>
