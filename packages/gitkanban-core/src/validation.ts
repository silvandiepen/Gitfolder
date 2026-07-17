import { getCardFields } from './card.js'
import type { EffectiveConfig, ParsedCard } from './types.js'

export interface ValidationResult {
  valid: boolean
  errors: string[]
}

/**
 * Validate a card against a project's effective config. A card that references
 * an id absent from the effective config (status/priority/type/assignee/epic) is
 * a configuration error — the entry should be added or the card corrected.
 */
export function validateCard(config: EffectiveConfig, card: ParsedCard): ValidationResult {
  const errors: string[] = []
  const f = getCardFields(card)

  if (!f.id) errors.push('missing required field: id')
  if (!f.title) errors.push('missing required field: title')
  if (!f.status) {
    errors.push('missing required field: status')
  } else if (!config.lanes.some((lane) => lane.status === f.status)) {
    errors.push(`status "${f.status}" matches no lane`)
  }

  if (f.priority && !config.priorities.some((p) => p.id === f.priority)) {
    errors.push(`priority "${f.priority}" is not a configured priority`)
  }
  if (f.type && !config.types.includes(f.type)) {
    errors.push(`type "${f.type}" is not a configured type`)
  }
  if (f.assignee && !config.users.some((u) => u.id === f.assignee)) {
    errors.push(`assignee "${f.assignee}" is not a configured user`)
  }
  if (f.epic && !config.epics.some((e) => e.id === f.epic)) {
    errors.push(`epic "${f.epic}" is not a configured epic`)
  }

  return { valid: errors.length === 0, errors }
}
