import { describe, expect, it } from 'vitest'
import {
  extractLabeledValue,
  extractSection,
  getCardFields,
  groupIntoColumns,
  parseAuditFilename,
  parseCard,
  resolveCardFields,
  resolveEffectiveConfig,
  validateCard,
} from '../src/index.js'
import type { BoardConfig } from '../src/index.js'

// A representative legacy audit/tasks card: fields live in the body, not frontmatter.
const AUDIT_CARD = `# ARC-0004 — Thread shadows the shared LuysKit.SoftIconButton

**Project:** Luys
**Priority:** P3 · Low
**Category:** duplication

---

## Impact

Thread defines an internal struct that re-implements the shared control.

## Recommended fix

Delete Thread's local copy and adopt the shared one.

## Acceptance criteria

- [ ] Root cause addressed

## Status

- **State:** in-progress

- **Assignee:** sil

- **Branch / PR:** —
`

const auditRoot: BoardConfig = {
  lanes: [
    { id: 'todo', name: 'To do', folder: '1. To do', status: 'todo' },
    { id: 'in-progress', name: 'In Progress', folder: '2. In Progress', status: 'in-progress' },
    { id: 'done', name: 'Done', folder: '5. Done', status: 'done', terminal: true },
  ],
  users: [{ id: 'sil' }],
  epics: [],
  priorities: [{ id: 'P3' }],
  types: [],
  tags: [],
  fieldSource: { mode: 'body-section', section: 'Status', map: { status: 'State', assignee: 'Assignee' } },
}
const config = resolveEffectiveConfig(auditRoot, { project: 'Luys' })

describe('markdown extraction helpers', () => {
  it('extracts a section body up to the next heading', () => {
    const section = extractSection(AUDIT_CARD, 'Status')
    expect(section).toContain('**State:** in-progress')
    expect(section).not.toContain('Root cause addressed')
  })

  it('reads a bold-labelled value, treating placeholders as null', () => {
    const section = extractSection(AUDIT_CARD, 'Status')
    expect(extractLabeledValue(section, 'State')).toBe('in-progress')
    expect(extractLabeledValue(section, 'Assignee')).toBe('sil')
    expect(extractLabeledValue(section, 'Branch / PR')).toBeNull()
  })
})

describe('body-section field source', () => {
  it('resolves status/assignee from the Status section and title from the H1', () => {
    const f = resolveCardFields(parseCard(AUDIT_CARD), config.fieldSource)
    expect(f.status).toBe('in-progress')
    expect(f.assignee).toBe('sil')
    expect(f.title).toContain('Thread shadows the shared')
  })

  it('falls back to frontmatter when the field source is frontmatter/default', () => {
    const fmCard = parseCard('---\nid: X-1\ntitle: t\nstatus: done\n---\n\nbody\n')
    expect(resolveCardFields(fmCard).status).toBe('done')
    expect(getCardFields(fmCard).status).toBe('done')
  })

  it('groups body-section cards into the right lane', () => {
    const { columns, uncategorised } = groupIntoColumns(config, [parseCard(AUDIT_CARD)])
    expect(uncategorised).toHaveLength(0)
    const inProgress = columns.find((c) => c.lane.id === 'in-progress')
    expect(inProgress?.cards).toHaveLength(1)
  })

  it('validates the resolvable body-section fields; id comes from the filename', () => {
    const result = validateCard(config, parseCard(AUDIT_CARD))
    // status ('in-progress') and assignee ('sil') resolve and pass; the id is not
    // in the body — a loader supplies it from the filename.
    expect(result.errors).toEqual(['missing required field: id'])
    expect(parseAuditFilename('P3-ARC-0004-thread-shadows.md')?.id).toBe('ARC-0004')
  })
})

describe('parseAuditFilename', () => {
  it('splits P{n}-{CAT}-{NNNN}-{slug}.md, including alphanumeric categories', () => {
    expect(parseAuditFilename('P3-ARC-0004-thread-shadows-the-shared.md')).toEqual({
      priority: 'P3',
      id: 'ARC-0004',
      slug: 'thread-shadows-the-shared',
    })
    expect(parseAuditFilename('P1-A11Y-0001-dynamic-type.md')).toEqual({
      priority: 'P1',
      id: 'A11Y-0001',
      slug: 'dynamic-type',
    })
  })

  it('returns null for non-matching names', () => {
    expect(parseAuditFilename('00-OVERVIEW.md')).toBeNull()
    expect(parseAuditFilename('GITKIT-001-foo.md')).toBeNull()
  })
})
