import { describe, expect, it } from 'vitest'
import { resolveEffectiveConfig } from '../src/index.js'
import type { BoardConfig, ProjectConfig } from '../src/index.js'

const root: BoardConfig = {
  lanes: [
    { id: 'todo', name: 'To do', folder: '1. To do', status: 'todo' },
    { id: 'in-progress', name: 'In Progress', folder: '2. In Progress', status: 'in-progress' },
    { id: 'done', name: 'Done', folder: '5. Done', status: 'done', terminal: true },
  ],
  users: [
    { id: 'sil', name: 'Sil', kind: 'human' },
    { id: 'herma', name: 'Herma', kind: 'agent' },
  ],
  epics: [],
  priorities: [
    { id: 'P0', name: 'Blocker' },
    { id: 'P1', name: 'High' },
  ],
  types: ['fix', 'feature'],
  tags: ['native'],
}

describe('config inheritance', () => {
  it('inherits root lanes when the project defines none', () => {
    const eff = resolveEffectiveConfig(root, { project: 'imagekid', lanes: [] })
    expect(eff.lanes.map((l) => l.id)).toEqual(['todo', 'in-progress', 'done'])
  })

  it('replaces lanes entirely when the project defines its own workflow', () => {
    const project: ProjectConfig = {
      project: 'Outreach',
      lanes: [
        { id: 'backlog', name: 'Backlog', folder: '1. Backlog', status: 'backlog' },
        { id: 'won', name: 'Won', folder: '4. Won', status: 'won', terminal: true },
      ],
    }
    const eff = resolveEffectiveConfig(root, project)
    expect(eff.lanes.map((l) => l.id)).toEqual(['backlog', 'won'])
  })

  it('merges vocabularies: project entries extend root', () => {
    const eff = resolveEffectiveConfig(root, {
      project: 'imagekid',
      users: [{ id: 'hermina', name: 'Hermina', kind: 'agent' }],
      types: ['security', 'fix'],
    })
    expect(eff.users.map((u) => u.id)).toEqual(['sil', 'herma', 'hermina'])
    // types union preserves root order and appends only the new value.
    expect(eff.types).toEqual(['fix', 'feature', 'security'])
  })

  it('lets a project entry override a root entry with the same id', () => {
    const eff = resolveEffectiveConfig(root, {
      project: 'imagekid',
      users: [{ id: 'sil', name: 'Sil van Diepen', kind: 'human', role: 'owner' }],
    })
    const sil = eff.users.find((u) => u.id === 'sil')
    expect(sil?.role).toBe('owner')
    expect(sil?.name).toBe('Sil van Diepen')
    // Order is unchanged; sil stays first, no duplicate added.
    expect(eff.users.map((u) => u.id)).toEqual(['sil', 'herma'])
  })

  it('does not mutate the root config', () => {
    resolveEffectiveConfig(root, { lanes: [{ id: 'x', name: 'X', folder: 'x', status: 'x' }] })
    expect(root.lanes.map((l) => l.id)).toEqual(['todo', 'in-progress', 'done'])
  })
})
