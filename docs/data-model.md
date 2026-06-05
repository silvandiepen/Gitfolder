# Data Model

## Goal

GitFolder needs a small local data model that is boring, explicit, and safe.

Phase 1 stores all app configuration locally on the Mac. There is no backend account system, no hosted database, and no product cloud. GitHub is only used as the Git remote selected by the user.

Suggested storage path:

```txt
~/Library/Application Support/GitFolder/config.json
~/Library/Application Support/GitFolder/logs/
```

If the app is sandboxed, selected folders should be stored using macOS security-scoped bookmarks, not only raw paths.

## Product licensing model

Phase 1 is a paid App Store utility.

```ts
type ProductLicense = {
  purchaseModel: 'app_store_paid_upfront'
  priceEur: 5
  entitlement: 'lifetime'
  trial: false
  subscription: false
  inAppPurchases: false
}
```

Notes:

- The user pays once in the Mac App Store.
- No account is needed for licensing in Phase 1.
- No subscription, no consumables, no paid upgrades in Phase 1.
- Later major paid upgrades can be considered as a separate product decision, but should not complicate v1.

## Core types

These TypeScript types describe the contract. The native app will implement equivalent Swift models.

```ts
type ISODateTime = string

type SyncStatus =
  | 'idle'
  | 'checking'
  | 'syncing'
  | 'synced'
  | 'paused'
  | 'waiting_for_connection'
  | 'needs_attention'
  | 'error'
  | 'conflict'

type SyncIntervalMinutes = 5 | 15 | 30 | 60

type GitProvider = 'github'

type GitAuthMode = 'ssh'

type SyncedFolder = {
  id: string
  name: string
  localPath: string
  bookmarkData?: string
  repoUrl: string
  provider: GitProvider
  authMode: GitAuthMode
  branch: string
  syncIntervalMinutes: SyncIntervalMinutes
  enabled: boolean
  createdAt: ISODateTime
  updatedAt: ISODateTime
  lastSyncAt?: ISODateTime
  lastSuccessfulSyncAt?: ISODateTime
  lastCheckedAt?: ISODateTime
  lastStatus: SyncStatus
  lastError?: UserFacingError
  git?: GitRepositoryState
  safety?: FolderSafetyState
}
```

## App configuration

```ts
type GitFolderConfig = {
  schemaVersion: 1
  app: AppSettings
  license: ProductLicense
  folders: SyncedFolder[]
}

type AppSettings = {
  launchAtLogin: boolean
  pauseAllSyncing: boolean
  defaultSyncIntervalMinutes: SyncIntervalMinutes
  defaultBranch: string
  showNotificationsFor: NotificationEvent[]
  logRetentionDays: number
}

type NotificationEvent =
  | 'sync_failed'
  | 'github_access_failed'
  | 'folder_permission_lost'
  | 'conflict_detected'
```

Phase 1 defaults:

```ts
const defaultAppSettings: AppSettings = {
  launchAtLogin: false,
  pauseAllSyncing: false,
  defaultSyncIntervalMinutes: 15,
  defaultBranch: 'main',
  showNotificationsFor: [
    'sync_failed',
    'github_access_failed',
    'folder_permission_lost',
    'conflict_detected',
  ],
  logRetentionDays: 30,
}
```

## Git state

GitFolder should keep lightweight Git metadata so it can explain state and avoid repeating dangerous actions.

```ts
type GitRepositoryState = {
  isGitRepository: boolean
  remoteName: 'origin'
  remoteUrl: string
  branch: string
  upstreamBranch?: string
  lastKnownLocalHead?: string
  lastKnownRemoteHead?: string
  hasUncommittedChanges: boolean
  hasUntrackedFiles: boolean
  hasUnpushedCommits: boolean
  hasDivergedFromRemote: boolean
  hasMergeInProgress: boolean
  hasRebaseInProgress: boolean
}
```

Important rule:

If `hasMergeInProgress`, `hasRebaseInProgress`, or `hasDivergedFromRemote` is true, GitFolder should pause that folder and mark it as `needs_attention` or `conflict`. Do not keep trying to sync.

## Safety state

```ts
type FolderSafetyState = {
  lastScannedAt?: ISODateTime
  estimatedFileCount?: number
  estimatedSizeBytes?: number
  largeFolderWarningShown: boolean
  sensitiveFileWarningShown: boolean
  detectedSensitivePatterns: SensitivePattern[]
  detectedLargeFiles: LargeFileWarning[]
  ignoreFileCreatedByGitFolder: boolean
}

type SensitivePattern = {
  path: string
  kind:
    | 'env_file'
    | 'private_key'
    | 'certificate'
    | 'database'
    | 'credential_file'
    | 'unknown_sensitive'
}

type LargeFileWarning = {
  path: string
  sizeBytes: number
}
```

Phase 1 should warn before first sync when it detects obvious sensitive or huge files. It does not need a perfect secret scanner. It needs good enough guardrails.

Minimum sensitive patterns:

```txt
.env
.env.*
*.pem
*.key
id_rsa
id_ed25519
*.p12
*.sqlite
*.sqlite3
*.db
```

## Sync run lifecycle

Each sync attempt should be represented as a run. Runs can be stored in memory during execution and appended to logs afterward.

```ts
type SyncRun = {
  id: string
  folderId: string
  startedAt: ISODateTime
  finishedAt?: ISODateTime
  trigger: SyncTrigger
  status: SyncRunStatus
  steps: SyncStep[]
  summary?: SyncSummary
  error?: UserFacingError
}

type SyncTrigger = 'interval' | 'manual' | 'startup' | 'retry'

type SyncRunStatus =
  | 'running'
  | 'no_changes'
  | 'committed_and_pushed'
  | 'committed_not_pushed'
  | 'paused'
  | 'failed'
  | 'conflict'

type SyncStep = {
  name:
    | 'check_folder'
    | 'resolve_bookmark'
    | 'check_git_available'
    | 'inspect_repository'
    | 'scan_safety'
    | 'fetch_remote'
    | 'check_changes'
    | 'debounce'
    | 'stage_changes'
    | 'commit_snapshot'
    | 'pull_rebase'
    | 'push'
    | 'update_status'
  startedAt: ISODateTime
  finishedAt?: ISODateTime
  status: 'running' | 'skipped' | 'success' | 'failed'
  technicalOutput?: string
}

type SyncSummary = {
  filesChanged: number
  commitSha?: string
  commitMessage?: string
  pushed: boolean
}
```

## Errors

User-facing errors should be short. Technical details belong in logs.

```ts
type UserFacingError = {
  code: GitFolderErrorCode
  title: string
  message: string
  recoverySuggestion?: string
  technicalDetailsLogId?: string
}

type GitFolderErrorCode =
  | 'folder_missing'
  | 'folder_access_needed'
  | 'git_not_available'
  | 'github_access_failed'
  | 'repo_mismatch'
  | 'remote_changed'
  | 'conflict_detected'
  | 'push_failed'
  | 'large_folder_warning'
  | 'sensitive_files_warning'
  | 'unknown_error'
```

Example:

```ts
const conflictError: UserFacingError = {
  code: 'conflict_detected',
  title: 'Conflict detected',
  message: 'Sync paused because this folder has changes that conflict with GitHub.',
  recoverySuggestion: 'Open the folder in your Git client, resolve the conflict, then resume syncing.',
}
```

## Logs

Logs should be local, plain, and boring.

```ts
type LogEntry = {
  id: string
  createdAt: ISODateTime
  level: 'debug' | 'info' | 'warning' | 'error'
  folderId?: string
  syncRunId?: string
  message: string
  technicalDetails?: string
}
```

Recommended file layout:

```txt
logs/
  2026-06-05.jsonl
  2026-06-06.jsonl
```

Use JSON Lines so appending is simple and crash-safe enough for Phase 1.

## Website/docs data

The website is static documentation and marketing. It does not need a backend in Phase 1.

```ts
type WebsitePage = {
  slug: string
  title: string
  description: string
  bodyMarkdownPath: string
}

type DownloadLink = {
  label: string
  url: string
  kind: 'app_store'
}
```

Initial website pages:

- `/` — simple landing page
- `/docs` — docs index
- `/docs/getting-started`
- `/docs/github-ssh`
- `/docs/safety`
- `/docs/troubleshooting`
- `/privacy`
- `/support`

## Versioning and migrations

Config must include `schemaVersion` from day one.

Phase 1 migration policy:

- If `schemaVersion` is missing, treat config as invalid and back it up before creating a fresh config.
- If `schemaVersion` is older, run a small explicit migration function.
- Never silently delete folders from config during migration.

```ts
type ConfigMigration = {
  from: number
  to: number
  migrate: (input: unknown) => GitFolderConfig
}
```
