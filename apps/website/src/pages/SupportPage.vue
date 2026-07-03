<script setup lang="ts">
/**
 * @view SupportPage
 * Support and troubleshooting info for GitFolder.
 */
import MarketingLayout from '@/components/MarketingLayout.vue'
</script>

<template>
  <MarketingLayout>
    <div class="support">
      <div class="support__container">
        <h1 class="support__title">Support</h1>
        <p class="support__intro">GitFolder is a small app. Most issues come down to Git, GitHub token access, repository URLs, or folder permissions.</p>

        <section class="support__section">
          <h2>Check your setup</h2>
          <div class="support__steps">
            <div class="support__step">
              <span class="support__step-num">1</span>
              <div>
                <h4>Verify Git is installed</h4>
                <p>Open Terminal and run <code>git --version</code>. If not found, install Xcode Command Line Tools: <code>xcode-select --install</code>.</p>
              </div>
            </div>
            <div class="support__step">
              <span class="support__step-num">2</span>
              <div>
                <h4>Test GitHub access</h4>
                <p>Open GitFolder Settings, paste a fine-grained GitHub token, enter the repository URL, and run Test GitHub Access.</p>
              </div>
            </div>
            <div class="support__step">
              <span class="support__step-num">3</span>
              <div>
                <h4>Check the repository URL</h4>
                <p>Make sure the URL in GitFolder matches the HTTPS URL on your GitHub repository page. It should start with <code>https://github.com/</code>. SSH URLs are available under Advanced settings.</p>
              </div>
            </div>
          </div>
        </section>

        <section class="support__section">
          <h2>Common issues</h2>
          <div class="support__faq">
            <div class="support__faq-item">
              <h4>Folder shows "Error" status</h4>
              <p>Open Settings and check the error message. The most common causes are a missing token, a token without repository access, an incorrect repository URL, or a folder permission that needs to be refreshed.</p>
            </div>
            <div class="support__faq-item">
              <h4>Folder shows "Needs attention"</h4>
              <p>There's a Git conflict. Resolve it in your preferred Git client, then resume syncing in GitFolder.</p>
            </div>
            <div class="support__faq-item">
              <h4>Changes not appearing on GitHub</h4>
              <p>Check that the folder isn't paused, the sync interval hasn't elapsed yet, and the repository URL is correct. You can force a sync with "Sync Now".</p>
            </div>
          </div>
        </section>

        <section class="support__section">
          <h2>Still stuck?</h2>
          <p>Open an issue on <a href="https://github.com/silvandiepen/Gitfolder" target="_blank" rel="noopener">GitHub</a> with the error message from Settings and your macOS version. Technical Git output is kept in local logs so sync errors can be diagnosed without exposing details in the menu bar.</p>
        </section>
      </div>
    </div>
  </MarketingLayout>
</template>

<style lang="scss" scoped>
.support {
  &__container {
    max-width: 720px;
    margin: 0 auto;
    padding: 48px 32px 96px;
  }

  @include e(title) {
    font-size: var(--font-size-xxl);
    font-weight: var(--font-weight-bold);
    margin-bottom: 16px;
  }

  @include e(intro) {
    font-size: var(--font-size-base);
    color: var(--color-text-secondary);
    line-height: var(--line-height-relaxed);
    margin-bottom: 48px;
  }

  @include e(section) {
    margin-bottom: 48px;

    h2 {
      font-size: var(--font-size-lg);
      font-weight: var(--font-weight-semibold);
      margin-bottom: 20px;
      padding-bottom: 12px;
      border-bottom: 1px solid var(--color-border-light);
    }

    p {
      font-size: var(--font-size-sm);
      color: var(--color-text-secondary);
      line-height: var(--line-height-relaxed);

      code {
        background: var(--color-surface-raised);
        padding: 2px 6px;
        border-radius: 4px;
        font-family: 'SF Mono', 'Fira Code', monospace;
        font-size: var(--font-size-xs);
      }
    }
  }

  @include e(steps) {
    display: flex;
    flex-direction: column;
    gap: 20px;
  }

  @include e(step) {
    display: flex;
    gap: 16px;
    align-items: flex-start;

    h4 {
      font-weight: var(--font-weight-semibold);
      margin-bottom: 4px;
    }

    p {
      font-size: var(--font-size-sm);
      color: var(--color-text-secondary);
      line-height: var(--line-height-relaxed);
    }
  }

  @include e(step-num) {
    flex-shrink: 0;
    width: 32px;
    height: 32px;
    border-radius: 50%;
    background: var(--color-accent-tint);
    color: var(--color-accent);
    font-size: var(--font-size-sm);
    font-weight: var(--font-weight-semibold);
    display: flex;
    align-items: center;
    justify-content: center;
  }

  @include e(faq) {
    display: flex;
    flex-direction: column;
    gap: 24px;
  }

  @include e(faq-item) {
    h4 {
      font-size: var(--font-size-base);
      font-weight: var(--font-weight-semibold);
      margin-bottom: 8px;
    }

    p {
      font-size: var(--font-size-sm);
      color: var(--color-text-secondary);
      line-height: var(--line-height-relaxed);
    }
  }
}
</style>
