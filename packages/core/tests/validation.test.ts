import { describe, expect, it } from 'vitest'
import { createDefaultConfig, defaultLicense } from '../src/index.js'
import { isAllowedSyncInterval, validateConfig, validateSyncedFolder } from '../src/validation.js'

describe('GitFolder core contracts', () => {
  it('uses the paid App Store lifetime license model', () => {
    expect(defaultLicense).toEqual({
      purchaseModel: 'app_store_paid_upfront',
      priceEur: 5,
      entitlement: 'lifetime',
      trial: false,
      subscription: false,
      inAppPurchases: false,
    })
  })

  it('creates a valid empty default config', () => {
    expect(validateConfig(createDefaultConfig())).toEqual({ valid: true, errors: [] })
  })

  it('accepts only the supported sync intervals', () => {
    expect(isAllowedSyncInterval(5)).toBe(true)
    expect(isAllowedSyncInterval(15)).toBe(true)
    expect(isAllowedSyncInterval(30)).toBe(true)
    expect(isAllowedSyncInterval(60)).toBe(true)
    expect(isAllowedSyncInterval(10)).toBe(false)
  })

  it('reports missing required folder fields', () => {
    const result = validateSyncedFolder({ provider: 'github', authMode: 'ssh' })

    expect(result.valid).toBe(false)
    expect(result.errors).toContain('folder.id is required')
    expect(result.errors).toContain('folder.repoUrl is required')
  })
})
