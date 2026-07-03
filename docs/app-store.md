# App Store and Business Model

## Sales model

GitFolder v1 is a paid Mac App Store app.

```txt
Price: €5
Purchase: one-time
Entitlement: lifetime for v1
Distribution: Mac App Store only
Subscriptions: no
In-app purchases: no
Trial: no
```

## Why this model fits

GitFolder is a focused utility. A one-time paid download is simpler and more honest than a subscription.

The app does not need:

- user accounts
- billing backend
- license server
- Stripe/Paddle checkout
- hosted dashboard
- subscription entitlement checks

Apple handles purchase and distribution. GitFolder stays local-first.

## App Store category

Likely category:

- Developer Tools

Alternative:

- Productivity

Developer Tools is probably more honest for Phase 1 because the user connects GitHub repositories and understands folders as versioned snapshots.

## App Store copy draft

### Name

GitFolder

### Subtitle

Automatic Git snapshots for folders

### Keywords

```txt
git,github,backup,versioning,snapshot,folder,sync,developer
```

### Category

```txt
Primary: Developer Tools
Secondary: Productivity
```

### Age rating

```txt
4+
No objectionable content, user-generated content browsing, commerce, gambling, or unrestricted web access.
```

### Support URL

```txt
https://gitfolder.app/support
```

### Privacy URL

```txt
https://gitfolder.app/privacy
```

### Screenshots

Required Mac App Store screenshots should show:

- Menu bar status with configured folders
- Settings with GitHub Token access test
- Folder configuration with HTTPS repository URL
- Sync success state after a snapshot commit

### Short description

GitFolder is a small Mac menu bar app that automatically versions selected folders with GitHub.

Pick a folder, connect a repository, choose a sync interval, and GitFolder creates quiet snapshot commits in the background whenever files change.

### Key points

- One-time €5 purchase
- No subscription
- Menu bar utility
- Uses a GitHub fine-grained token stored in macOS Keychain
- Supports SSH as an advanced option
- Automatic snapshot commits
- Manual Sync Now action
- Pause all syncing or individual folders
- Clear status and local logs
- No custom cloud sync service

## Privacy stance

Phase 1 should be privacy-simple:

- No GitFolder account
- No analytics by default
- No custom backend
- No app-owned cloud storage
- No file contents sent to GitFolder servers
- User-selected folders are read locally
- File changes are committed and pushed directly to GitHub repositories configured by the user
- GitHub tokens are stored in macOS Keychain, not in GitFolder config JSON
- GitFolder transmits selected folder contents to the user's configured GitHub repositories for app functionality

Required website pages before App Store submission:

- `/privacy`
- `/support`

## App Store review notes

The review notes should explain:

```txt
GitFolder is a macOS menu bar utility. It requires the user to select a local folder, provide a GitHub HTTPS repository URL, and paste a fine-grained GitHub token. The token is stored in macOS Keychain and is used only to run Git commands against the user's configured repositories. SSH repository URLs remain available under Advanced settings for users with an existing SSH setup.
```

If the app requires Git to be installed, say that clearly in onboarding and App Store copy. If relying on Apple Command Line Tools Git, provide setup guidance when Git is unavailable.

## Pricing note

A €5 lifetime price means v1 must stay lean. Do not add costs that require recurring revenue unless the product model changes.

Avoid in v1:

- hosted sync
- background cloud workers
- support-heavy collaboration features
- account recovery systems
- paid API dependencies

The product should be a small local Mac utility that users buy once and understand immediately.
