export type ISODateTime = string

export type ProductLicense = {
  purchaseModel: 'app_store_paid_upfront'
  priceEur: 5
  entitlement: 'lifetime'
  trial: false
  subscription: false
  inAppPurchases: false
}

export type SyncStatus =
  | 'idle'
  | 'checking'
  | 'syncing'
  | 'synced'
  | 'paused'
  | 'waiting_for_connection'
  | 'needs_attention'
  | 'error'
  | 'conflict'

export type SyncIntervalMinutes = 5 | 15 | 30 | 60
export type GitProvider = 'github'
export type GitAuthMode = 'ssh'

export type GitFolderConfig = {
  schemaVersion: 1
  app: AppSettings
  license: ProductLicense
  folders: SyncedFolder[]
}

export type AppSettings = {
  launchAtLogin: boolean
  pauseAllSyncing: boolean
  defaultSyncIntervalMinutes: SyncIntervalMinutes
  defaultBranch: string
  showNotificationsFor: NotificationEvent[]
  logRetentionDays: number
}

export type NotificationEvent =
  | 'sync_failed'
  | 'github_access_failed'
  | 'folder_permission_lost'
  | 'conflict_detected'

export type SyncedFolder = {
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

export type GitRepositoryState = {
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

export type FolderSafetyState = {
  lastScannedAt?: ISODateTime
  estimatedFileCount?: number
  estimatedSizeBytes?: number
  largeFolderWarningShown: boolean
  sensitiveFileWarningShown: boolean
  detectedSensitivePatterns: SensitivePattern[]
  detectedLargeFiles: LargeFileWarning[]
  ignoreFileCreatedByGitFolder: boolean
}

export type SensitivePattern = {
  path: string
  kind:
    | 'env_file'
    | 'private_key'
    | 'certificate'
    | 'database'
    | 'credential_file'
    | 'unknown_sensitive'
}

export type LargeFileWarning = {
  path: string
  sizeBytes: number
}

export type SyncRun = {
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

export type SyncTrigger = 'interval' | 'manual' | 'startup' | 'retry'

export type SyncRunStatus =
  | 'running'
  | 'no_changes'
  | 'committed_and_pushed'
  | 'committed_not_pushed'
  | 'paused'
  | 'failed'
  | 'conflict'

export type SyncStep = {
  name: SyncStepName
  startedAt: ISODateTime
  finishedAt?: ISODateTime
  status: 'running' | 'skipped' | 'success' | 'failed'
  technicalOutput?: string
}

export type SyncStepName =
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

export type SyncSummary = {
  filesChanged: number
  commitSha?: string
  commitMessage?: string
  pushed: boolean
}

export type UserFacingError = {
  code: GitFolderErrorCode
  title: string
  message: string
  recoverySuggestion?: string
  technicalDetailsLogId?: string
}

export type GitFolderErrorCode =
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

export type LogEntry = {
  id: string
  createdAt: ISODateTime
  level: 'debug' | 'info' | 'warning' | 'error'
  folderId?: string
  syncRunId?: string
  message: string
  technicalDetails?: string
}
