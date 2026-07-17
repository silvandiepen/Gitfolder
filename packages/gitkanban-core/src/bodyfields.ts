import type { CardFields, FieldSource, ParsedCard } from './types.js'

/**
 * Extracting card fields from a markdown body, for boards (like the legacy
 * `audit/tasks` format) that keep fields as `**Label:** value` lines rather than
 * in YAML frontmatter.
 */

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

/** The first `# H1` line of a body, without the leading `# `. */
export function extractTitle(body: string): string {
  const match = body.match(/^#\s+(.+?)\s*$/m)
  return match ? match[1].trim() : ''
}

/**
 * The text of a markdown section by heading name, from the heading up to (but not
 * including) the next heading of any level, or end of document.
 */
export function extractSection(body: string, section: string): string {
  const heading = new RegExp(`^#{1,6}\\s+${escapeRegExp(section)}\\s*$`, 'im')
  const match = heading.exec(body)
  if (!match) return ''
  const rest = body.slice(match.index + match[0].length)
  const next = rest.search(/^#{1,6}\s+/m)
  return next === -1 ? rest : rest.slice(0, next)
}

/**
 * The value following a bold `**Label:**` (optionally a `- ` list item, and with
 * the colon inside or outside the bold). Returns null when the label is absent or
 * its value is an "unset" placeholder (`—`, `-`, empty, `None`, `N/A`, `TBD`).
 */
export function extractLabeledValue(text: string, label: string): string | null {
  const re = new RegExp(`\\*\\*\\s*${escapeRegExp(label)}\\s*:?\\s*\\*\\*\\s*:?\\s*(.*)`, 'im')
  const match = re.exec(text)
  if (!match) return null
  return normalizeValue(match[1])
}

function normalizeValue(raw: string): string | null {
  const value = raw.replace(/`/g, '').trim()
  if (value === '' || value === '—' || value === '-' || /^(none|n\/a|tbd)$/i.test(value)) {
    return null
  }
  return value
}

/**
 * Resolve a card's fields from a body-section field source. `status`/`assignee`
 * (and any other mapped labels) are read from the named section, falling back to
 * the whole body (so a top metadata block is also matched). `title` falls back to
 * the H1 heading.
 */
export function resolveBodySectionFields(card: ParsedCard, source: Extract<FieldSource, { mode: 'body-section' }>): CardFields {
  const body = card.body
  const section = source.section ? extractSection(body, source.section) : ''
  const get = (field: string): string | null => {
    const label = source.map[field]
    if (!label) return null
    return extractLabeledValue(section, label) ?? extractLabeledValue(body, label)
  }
  return {
    id: get('id') ?? '',
    title: get('title') ?? extractTitle(body),
    project: get('project') ?? '',
    status: get('status') ?? '',
    priority: get('priority'),
    type: get('type'),
    epic: get('epic'),
    assignee: get('assignee'),
    order: null,
  }
}

/**
 * Parse an audit-task filename `P{n}-{CAT}-{NNNN}-{slug}.md` into its parts.
 * The legacy boards encode priority and a stable id in the filename, which the
 * body does not carry cleanly. Returns null for names that don't match.
 */
export function parseAuditFilename(filename: string): { priority: string; id: string; slug: string } | null {
  const base = filename.replace(/\.md$/i, '')
  const match = base.match(/^(P\d+)-([A-Z0-9]+-\d+)-(.+)$/)
  if (!match) return null
  return { priority: match[1], id: match[2], slug: match[3] }
}
