import type { AppSettings, GitFolderConfig, ProductLicense, SyncIntervalMinutes } from './models.js'

export const allowedSyncIntervals = [5, 15, 30, 60] as const satisfies readonly SyncIntervalMinutes[]

export const defaultLicense: ProductLicense = {
  purchaseModel: 'app_store_paid_upfront',
  priceEur: 5,
  entitlement: 'lifetime',
  trial: false,
  subscription: false,
  inAppPurchases: false,
}

export const defaultAppSettings: AppSettings = {
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

export function createDefaultConfig(): GitFolderConfig {
  return {
    schemaVersion: 1,
    app: { ...defaultAppSettings, showNotificationsFor: [...defaultAppSettings.showNotificationsFor] },
    license: { ...defaultLicense },
    folders: [],
  }
}
