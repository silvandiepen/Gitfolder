import { allowedSyncIntervals } from './defaults.js'
import type { GitFolderConfig, SyncedFolder, SyncIntervalMinutes } from './models.js'

export type ValidationResult = {
  valid: boolean
  errors: string[]
}

export function isAllowedSyncInterval(value: unknown): value is SyncIntervalMinutes {
  return typeof value === 'number' && allowedSyncIntervals.includes(value as SyncIntervalMinutes)
}

export function validateSyncedFolder(folder: Partial<SyncedFolder>): ValidationResult {
  const errors: string[] = []

  if (!folder.id) errors.push('folder.id is required')
  if (!folder.name) errors.push('folder.name is required')
  if (!folder.localPath) errors.push('folder.localPath is required')
  if (!folder.repoUrl) errors.push('folder.repoUrl is required')
  if (folder.provider !== 'github') errors.push('folder.provider must be github')
  if (folder.authMode !== 'ssh') errors.push('folder.authMode must be ssh')
  if (!folder.branch) errors.push('folder.branch is required')
  if (!isAllowedSyncInterval(folder.syncIntervalMinutes)) {
    errors.push('folder.syncIntervalMinutes must be one of 5, 15, 30, or 60')
  }
  if (typeof folder.enabled !== 'boolean') errors.push('folder.enabled must be boolean')
  if (!folder.createdAt) errors.push('folder.createdAt is required')
  if (!folder.updatedAt) errors.push('folder.updatedAt is required')
  if (!folder.lastStatus) errors.push('folder.lastStatus is required')

  return { valid: errors.length === 0, errors }
}

export function validateConfig(config: Partial<GitFolderConfig>): ValidationResult {
  const errors: string[] = []

  if (config.schemaVersion !== 1) errors.push('schemaVersion must be 1')
  if (!config.app) errors.push('app settings are required')
  if (!config.license) errors.push('license is required')
  if (!Array.isArray(config.folders)) {
    errors.push('folders must be an array')
  } else {
    config.folders.forEach((folder, index) => {
      const result = validateSyncedFolder(folder)
      for (const error of result.errors) errors.push(`folders[${index}].${error}`)
    })
  }

  return { valid: errors.length === 0, errors }
}
