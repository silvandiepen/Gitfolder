<script setup lang="ts">
/**
 * @view DocsPage
 * Documentation page with sidebar navigation, matching Kod's DocsView pattern.
 */
import { ref } from 'vue'
import MarketingLayout from '@/components/MarketingLayout.vue'
import { appStoreUrl } from '../links'

const activeSection = ref('getting-started')

const sections = [
  { id: 'getting-started', label: 'Getting Started' },
  { id: 'install', label: 'Installation' },
  { id: 'adding-folders', label: 'Adding Folders' },
  { id: 'sync-settings', label: 'Sync Settings' },
  { id: 'ssh-keys', label: 'SSH Keys' },
  { id: 'troubleshooting', label: 'Troubleshooting' },
  { id: 'faq', label: 'FAQ' },
]

function scrollTo(id: string) {
  activeSection.value = id
  document.getElementById(id)?.scrollIntoView({ behavior: 'smooth', block: 'start' })
}
</script>

<template>
  <MarketingLayout>
    <div class="docs">
      <div class="docs__container">
        <div class="docs__layout">
          <!-- Sidebar -->
          <aside class="docs__sidebar">
            <h3 class="docs__sidebar-title">Documentation</h3>
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
            <!-- Getting Started -->
            <section id="getting-started" class="docs__section">
              <h2 class="docs__section-title">Getting Started</h2>
              <div class="docs__steps">
                <div class="docs__step">
                  <span class="docs__step-num">1</span>
                  <div>
                    <h4>Install GitFolder</h4>
                    <p><a :href="appStoreUrl" target="_blank" rel="noopener">Download GitFolder from the Mac App Store</a>. It lives in your menu bar — no dock icon.</p>
                  </div>
                </div>
                <div class="docs__step">
                  <span class="docs__step-num">2</span>
                  <div>
                    <h4>Make sure Git is installed</h4>
                    <p>GitFolder uses your system Git. Open Terminal and run <code>git --version</code> to verify. If Git isn't installed, macOS will prompt you to install Xcode Command Line Tools.</p>
                  </div>
                </div>
                <div class="docs__step">
                  <span class="docs__step-num">3</span>
                  <div>
                    <h4>Set up GitHub SSH</h4>
                    <p>GitFolder pushes over SSH. Make sure <code>ssh -T git@github.com</code> works in Terminal. If you need to set up SSH keys, follow <a href="https://docs.github.com/en/authentication/connecting-to-github-with-ssh" target="_blank" rel="noopener">GitHub's SSH guide</a>.</p>
                  </div>
                </div>
              </div>
            </section>

            <!-- Installation -->
            <section id="install" class="docs__section">
              <h2 class="docs__section-title">Installation</h2>
              <div class="docs__steps">
                <div class="docs__step">
                  <span class="docs__step-num">1</span>
                  <div>
                    <h4>Mac App Store</h4>
                    <p><a :href="appStoreUrl" target="_blank" rel="noopener">Get GitFolder from the Mac App Store</a>. It's a single purchase — no subscription.</p>
                  </div>
                </div>
                <div class="docs__step">
                  <span class="docs__step-num">2</span>
                  <div>
                    <h4>Launch and open Settings</h4>
                    <p>Click the folder icon in the menu bar, then click the gear icon to open Settings. This is where you configure Git identity and add folders.</p>
                  </div>
                </div>
              </div>
            </section>

            <!-- Adding Folders -->
            <section id="adding-folders" class="docs__section">
              <h2 class="docs__section-title">Adding Folders</h2>
              <div class="docs__steps">
                <div class="docs__step">
                  <span class="docs__step-num">1</span>
                  <div>
                    <h4>Open Settings → Repositories</h4>
                    <p>Click the folder icon in the menu bar, then the gear icon. Go to the Repositories tab and click "Add Repository…".</p>
                  </div>
                </div>
                <div class="docs__step">
                  <span class="docs__step-num">2</span>
                  <div>
                    <h4>Choose a local folder</h4>
                    <p>Use the macOS folder picker to select the folder you want to version. GitFolder will request access to this folder.</p>
                  </div>
                </div>
                <div class="docs__step">
                  <span class="docs__step-num">3</span>
                  <div>
                    <h4>Paste a GitHub SSH URL</h4>
                    <p>Enter the SSH URL of the repository you want to push to, like <code>git@github.com:yourname/my-folder-backup.git</code>.</p>
                  </div>
                </div>
                <div class="docs__step">
                  <span class="docs__step-num">4</span>
                  <div>
                    <h4>Choose branch and interval</h4>
                    <p>Pick a branch name (default: <code>main</code>) and a sync interval (5, 15, 30, or 60 minutes). Click "Add and Sync" — GitFolder will run the first snapshot.</p>
                  </div>
                </div>
              </div>
            </section>

            <!-- Sync Settings -->
            <section id="sync-settings" class="docs__section">
              <h2 class="docs__section-title">Sync Settings</h2>
              <p>Configure syncing behavior in Settings → General:</p>
              <ul class="docs__list">
                <li><strong>Pause all syncing</strong> — temporarily stop all folder snapshots</li>
                <li><strong>Default interval</strong> — the default sync interval for new folders (5, 15, 30, or 60 minutes)</li>
                <li><strong>Per-folder override</strong> — each folder can have its own interval, branch, and pause state</li>
              </ul>
              <div class="docs__callout docs__callout--info">
                <div class="docs__callout-icon">💡</div>
                <div>
                  <h4>Sync All Now</h4>
                  <p>Click "Sync All Now" in the General tab or in the menu bar to trigger an immediate snapshot for all active folders, regardless of their interval.</p>
                </div>
              </div>
            </section>

            <!-- SSH Keys -->
            <section id="ssh-keys" class="docs__section">
              <h2 class="docs__section-title">SSH Keys</h2>
              <p>GitFolder uses SSH to push to GitHub. In most cases your existing SSH setup works out of the box.</p>

              <div class="docs__specs">
                <div class="docs__spec">
                  <span class="docs__spec-label">Default</span>
                  <span class="docs__spec-value">Uses system <code>~/.ssh</code></span>
                </div>
                <div class="docs__spec">
                  <span class="docs__spec-label">Custom key</span>
                  <span class="docs__spec-value">Choose a specific key in Settings → SSH</span>
                </div>
                <div class="docs__spec">
                  <span class="docs__spec-label">Sandbox</span>
                  <span class="docs__spec-value">Mac App Store builds may need explicit key selection</span>
                </div>
              </div>

              <div class="docs__callout docs__callout--warning">
                <div class="docs__callout-icon">⚠️</div>
                <div>
                  <h4>Mac App Store sandbox</h4>
                  <p>Sandboxed apps can't access <code>~/.ssh</code> directly. If you're using the Mac App Store version, go to Settings → SSH and choose your SSH private key file explicitly.</p>
                </div>
              </div>
            </section>

            <!-- Troubleshooting -->
            <section id="troubleshooting" class="docs__section">
              <h2 class="docs__section-title">Troubleshooting</h2>

              <div class="docs__callout docs__callout--warning">
                <div class="docs__callout-icon">⚠️</div>
                <div>
                  <h4>Folder shows "Error" status</h4>
                  <p>Check the error message in Settings → Repositories. Common causes:</p>
                  <ul class="docs__list">
                    <li>SSH key not configured or not accessible</li>
                    <li>Repository URL is wrong or you don't have push access</li>
                    <li>Branch doesn't exist yet and can't be created</li>
                    <li>Git conflict — resolve it manually in your Git client, then GitFolder will resume</li>
                  </ul>
                </div>
              </div>

              <div class="docs__steps" style="margin-top: 24px;">
                <div class="docs__step">
                  <span class="docs__step-num">1</span>
                  <div>
                    <h4>Verify Git is installed</h4>
                    <p>Open Terminal and run <code>git --version</code>. If not found, install Xcode Command Line Tools with <code>xcode-select --install</code>.</p>
                  </div>
                </div>
                <div class="docs__step">
                  <span class="docs__step-num">2</span>
                  <div>
                    <h4>Test SSH access</h4>
                    <p>Run <code>ssh -T git@github.com</code> in Terminal. You should see your GitHub username in the response.</p>
                  </div>
                </div>
                <div class="docs__step">
                  <span class="docs__step-num">3</span>
                  <div>
                    <h4>Check the repository URL</h4>
                    <p>Make sure the URL in GitFolder matches the SSH URL shown on your GitHub repository page. It should start with <code>git@github.com:</code>.</p>
                  </div>
                </div>
              </div>
            </section>

            <!-- FAQ -->
            <section id="faq" class="docs__section">
              <h2 class="docs__section-title">FAQ</h2>

              <div class="docs__faq">
                <div class="docs__faq-item">
                  <h4>Does GitFolder read my file contents?</h4>
                  <p>No. GitFolder uses Git to track changes. Git creates commits from your files — GitFolder just triggers the process. Your file data goes directly to your GitHub repository over SSH.</p>
                </div>
                <div class="docs__faq-item">
                  <h4>Can I use it with GitLab, Bitbucket, or self-hosted Git?</h4>
                  <p>GitFolder is designed for GitHub SSH URLs. Other Git hosts that support SSH may work if the URL format and authentication are compatible, but only GitHub is officially supported.</p>
                </div>
                <div class="docs__faq-item">
                  <h4>What happens if there's a merge conflict?</h4>
                  <p>GitFolder pauses the folder and shows a "Needs attention" status. Resolve the conflict in your preferred Git client, then resume syncing in GitFolder.</p>
                </div>
                <div class="docs__faq-item">
                  <h4>Does it need a GitFolder account?</h4>
                  <p>No. There is no GitFolder account, no cloud service, and no backend server. Everything runs locally on your Mac.</p>
                </div>
              </div>
            </section>
          </div>
        </div>
      </div>
    </div>
  </MarketingLayout>
</template>

<style lang="scss" scoped>
.docs {
  &__container {
    max-width: 1120px;
    margin: 0 auto;
    padding: 0 32px;
  }

  @include e(layout) {
    display: grid;
    grid-template-columns: 220px 1fr;
    gap: 48px;
    padding-top: 48px;
    padding-bottom: 96px;

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
    color: var(--color-text-tertiary);
    margin-bottom: 16px;
  }

  @include e(sidebar-nav) {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  @include e(sidebar-link) {
    display: block;
    text-align: left;
    font-size: var(--font-size-sm);
    font-weight: var(--font-weight-medium);
    color: var(--color-text-secondary);
    padding: 8px 12px;
    border-radius: 8px;
    transition: all var(--transition-fast);
    background: transparent;
    cursor: pointer;

    &:hover {
      color: var(--color-text-primary);
      background: var(--color-surface-raised);
    }

    @include m(active) {
      color: var(--color-accent);
      background: var(--color-accent-tint);
    }
  }

  // Content
  @include e(content) {
    min-width: 0;
  }

  @include e(section) {
    padding-top: 48px;
    &:first-child { padding-top: 0; }
  }

  @include e(section-title) {
    font-size: var(--font-size-xl);
    font-weight: var(--font-weight-bold);
    margin-bottom: 24px;
    padding-bottom: 12px;
    border-bottom: 1px solid var(--color-border-light);
  }

  p {
    font-size: var(--font-size-sm);
    color: var(--color-text-secondary);
    line-height: var(--line-height-relaxed);
    margin-bottom: 16px;

    code {
      background: var(--color-surface-raised);
      padding: 2px 6px;
      border-radius: 4px;
      font-family: 'SF Mono', 'Fira Code', monospace;
      font-size: var(--font-size-xs);
    }
  }

  // Steps
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

  // Lists
  @include e(list) {
    padding-left: 20px;
    display: flex;
    flex-direction: column;
    gap: 8px;

    li {
      font-size: var(--font-size-sm);
      color: var(--color-text-secondary);
      line-height: var(--line-height-relaxed);
      list-style: disc;

      code {
        background: var(--color-surface-raised);
        padding: 2px 6px;
        border-radius: 4px;
        font-family: 'SF Mono', 'Fira Code', monospace;
        font-size: var(--font-size-xs);
      }
    }
  }

  // Callouts
  @include e(callout) {
    display: flex;
    gap: 16px;
    padding: 20px 24px;
    border-radius: 16px;
    margin-top: 24px;

    @include m(warning) {
      background: #fef3cd;
      border: 1px solid color-mix(in srgb, #ffc92c, transparent 60%);
    }

    @include m(info) {
      background: var(--color-accent-tint);
      border: 1px solid color-mix(in srgb, var(--color-accent), transparent 60%);
    }

    h4 {
      font-weight: var(--font-weight-semibold);
      margin-bottom: 6px;
    }

    p {
      font-size: var(--font-size-sm);
      color: var(--color-text-secondary);
      line-height: var(--line-height-relaxed);
    }
  }

  @include e(callout-icon) {
    font-size: 20px;
    flex-shrink: 0;
    margin-top: 2px;
  }

  // Specs table
  @include e(specs) {
    display: flex;
    flex-direction: column;
    gap: 1px;
    background: var(--color-border-light);
    border-radius: 16px;
    overflow: hidden;
    margin-bottom: 24px;
  }

  @include e(spec) {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 14px 20px;
    background: var(--color-surface);

    code {
      background: var(--color-surface-raised);
      padding: 2px 6px;
      border-radius: 4px;
      font-family: 'SF Mono', 'Fira Code', monospace;
      font-size: var(--font-size-xs);
    }
  }

  @include e(spec-label) {
    font-size: var(--font-size-sm);
    font-weight: var(--font-weight-semibold);
  }

  @include e(spec-value) {
    font-size: var(--font-size-sm);
    color: var(--color-text-secondary);
  }

  // FAQ
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
