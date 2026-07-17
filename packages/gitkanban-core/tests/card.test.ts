import { describe, expect, it } from 'vitest'
import {
  getCardFields,
  groupIntoColumns,
  laneForStatus,
  parseCard,
  resolveEffectiveConfig,
  validateCard,
} from '../src/index.js'
import type { BoardConfig } from '../src/index.js'

const root: BoardConfig = {
  lanes: [
    { id: 'todo', name: 'To do', folder: '1. To do', status: 'todo' },
    { id: 'in-progress', name: 'In Progress', folder: '2. In Progress', status: 'in-progress' },
    { id: 'done', name: 'Done', folder: '5. Done', status: 'done', terminal: true },
  ],
  users: [{ id: 'sil' }, { id: 'herma' }],
  epics: [{ id: 'native-hardening' }],
  priorities: [{ id: 'P0' }, { id: 'P1' }, { id: 'P2' }],
  types: ['fix', 'feature'],
  tags: [],
}
const config = resolveEffectiveConfig(root, { project: 'imagekid' })

function card(fm: Record<string, unknown>) {
  return parseCard(`---\n${Object.entries(fm)
    .map(([k, v]) => `${k}: ${v === null ? 'null' : v}`)
    .join('\n')}\n---\n\nbody\n`)
}

describe('card fields and lanes', () => {
  it('reads modelled fields, defaulting the rest to null', () => {
    const f = getCardFields(card({ id: 'A-1', title: 'x', project: 'imagekid', status: 'todo' }))
    expect(f.id).toBe('A-1')
    expect(f.assignee).toBeNull()
    expect(f.epic).toBeNull()
  })

  it('maps status to a lane', () => {
    expect(laneForStatus(config, 'in-progress')?.folder).toBe('2. In Progress')
    expect(laneForStatus(config, 'nope')).toBeUndefined()
  })
})

describe('grouping into columns', () => {
  it('places cards in lane order and sorts within a lane by priority', () => {
    const cards = [
      card({ id: 'A-3', title: 'c', project: 'imagekid', status: 'todo', priority: 'P2' }),
      card({ id: 'A-1', title: 'a', project: 'imagekid', status: 'todo', priority: 'P0' }),
      card({ id: 'A-2', title: 'b', project: 'imagekid', status: 'in-progress', priority: 'P1' }),
    ]
    const { columns, uncategorised } = groupIntoColumns(config, cards)
    expect(columns.map((c) => c.lane.id)).toEqual(['todo', 'in-progress', 'done'])
    expect(columns[0].cards.map((c) => getCardFields(c).id)).toEqual(['A-1', 'A-3'])
    expect(columns[1].cards.map((c) => getCardFields(c).id)).toEqual(['A-2'])
    expect(uncategorised).toHaveLength(0)
  })

  it('collects cards whose status matches no lane instead of dropping them', () => {
    const cards = [card({ id: 'A-9', title: 'x', project: 'imagekid', status: 'archived' })]
    const { columns, uncategorised } = groupIntoColumns(config, cards)
    expect(columns.every((c) => c.cards.length === 0)).toBe(true)
    expect(uncategorised.map((c) => getCardFields(c).id)).toEqual(['A-9'])
  })
})

describe('validation', () => {
  it('accepts a card referencing only configured ids', () => {
    const result = validateCard(
      config,
      card({
        id: 'A-1',
        title: 'x',
        project: 'imagekid',
        status: 'todo',
        priority: 'P0',
        type: 'fix',
        assignee: 'sil',
        epic: 'native-hardening',
      }),
    )
    expect(result).toEqual({ valid: true, errors: [] })
  })

  it('flags references absent from the effective config', () => {
    const result = validateCard(
      config,
      card({
        id: 'A-2',
        title: 'x',
        project: 'imagekid',
        status: 'nope',
        priority: 'P9',
        assignee: 'ghost',
        epic: 'missing',
      }),
    )
    expect(result.valid).toBe(false)
    expect(result.errors).toEqual([
      'status "nope" matches no lane',
      'priority "P9" is not a configured priority',
      'assignee "ghost" is not a configured user',
      'epic "missing" is not a configured epic',
    ])
  })
})
