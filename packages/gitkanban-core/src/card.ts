import type { CardFields, EffectiveConfig, Lane, ParsedCard } from './types.js'

/** Read the modelled fields off a parsed card's frontmatter. */
export function getCardFields(card: ParsedCard): CardFields {
  const fm = card.frontmatter
  return {
    id: String(fm.id ?? ''),
    title: String(fm.title ?? ''),
    project: String(fm.project ?? ''),
    status: String(fm.status ?? ''),
    priority: (fm.priority as string | null) ?? null,
    type: (fm.type as string | null) ?? null,
    epic: (fm.epic as string | null) ?? null,
    assignee: (fm.assignee as string | null) ?? null,
    order: (fm.order as string | null) ?? null,
  }
}

/** The lane whose `status` matches the given status value, if any. */
export function laneForStatus(config: EffectiveConfig, status: string): Lane | undefined {
  return config.lanes.find((lane) => lane.status === status)
}

/** The lane a card belongs to, by its `status` frontmatter. */
export function laneForCard(config: EffectiveConfig, card: ParsedCard): Lane | undefined {
  return laneForStatus(config, getCardFields(card).status)
}

export interface Column {
  lane: Lane
  cards: ParsedCard[]
}

function priorityRank(config: EffectiveConfig, priority: string | null): number {
  if (!priority) return config.priorities.length
  const index = config.priorities.findIndex((p) => p.id === priority)
  return index === -1 ? config.priorities.length : index
}

/**
 * Compare two cards within the same lane. Order is:
 *   1. `order` rank key (lexicographic) when both have one,
 *   2. else priority (as configured, P0 before P1, …),
 *   3. else `created_at`,
 *   4. else `id`, for a stable result.
 * This lets rank-key boards and priority-ordered audit boards both sort sanely.
 */
export function compareCards(config: EffectiveConfig, a: ParsedCard, b: ParsedCard): number {
  const fa = getCardFields(a)
  const fb = getCardFields(b)
  if (fa.order && fb.order && fa.order !== fb.order) return fa.order < fb.order ? -1 : 1
  const pa = priorityRank(config, fa.priority ?? null)
  const pb = priorityRank(config, fb.priority ?? null)
  if (pa !== pb) return pa - pb
  const ca = String(a.frontmatter.created_at ?? '')
  const cb = String(b.frontmatter.created_at ?? '')
  if (ca !== cb) return ca < cb ? -1 : 1
  return fa.id < fb.id ? -1 : fa.id > fb.id ? 1 : 0
}

/**
 * Group cards into board columns in lane order. Cards whose `status` matches no
 * lane are returned in `uncategorised` rather than dropped.
 */
export function groupIntoColumns(
  config: EffectiveConfig,
  cards: ParsedCard[],
): { columns: Column[]; uncategorised: ParsedCard[] } {
  const columns: Column[] = config.lanes.map((lane) => ({ lane, cards: [] }))
  const byStatus = new Map<string, Column>()
  for (const column of columns) byStatus.set(column.lane.status, column)

  const uncategorised: ParsedCard[] = []
  for (const card of cards) {
    const status = getCardFields(card).status
    const column = byStatus.get(status)
    if (column) column.cards.push(card)
    else uncategorised.push(card)
  }

  for (const column of columns) column.cards.sort((a, b) => compareCards(config, a, b))
  return { columns, uncategorised }
}
