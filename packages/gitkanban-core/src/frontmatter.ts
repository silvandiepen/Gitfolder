import { parse as parseYaml, stringify as stringifyYaml } from 'yaml'
import type { ParsedCard } from './types.js'

const FRONTMATTER_RE = /^---\r?\n([\s\S]*?)\r?\n---\r?\n?/

export interface FrontmatterDocument {
  data: Record<string, unknown>
  body: string
  hasFrontmatter: boolean
}

/**
 * Split a markdown document into its YAML frontmatter object and its body.
 * A document with no leading `---` block yields an empty `data` and the whole
 * text as `body`.
 */
export function parseFrontmatter(text: string): FrontmatterDocument {
  const match = FRONTMATTER_RE.exec(text)
  if (!match) {
    return { data: {}, body: text, hasFrontmatter: false }
  }
  const yaml = match[1]
  const parsed = yaml.trim().length === 0 ? {} : parseYaml(yaml)
  const data = parsed && typeof parsed === 'object' ? (parsed as Record<string, unknown>) : {}
  const body = text.slice(match[0].length)
  return { data, body, hasFrontmatter: true }
}

/**
 * Re-assemble a markdown document from a frontmatter object and body.
 * All keys in `data` are written back, so keys the app does not model are
 * preserved. The body is emitted verbatim.
 */
export function serializeFrontmatter(data: Record<string, unknown>, body: string): string {
  const yaml = stringifyYaml(data, { lineWidth: 0 }).replace(/\n$/, '')
  return `---\n${yaml}\n---\n${body}`
}

/** Parse a card file into `{ frontmatter, body }`. */
export function parseCard(text: string): ParsedCard {
  const { data, body } = parseFrontmatter(text)
  return { frontmatter: data, body }
}

/** Serialize a parsed card back to a markdown string. */
export function serializeCard(card: ParsedCard): string {
  return serializeFrontmatter(card.frontmatter, card.body)
}
