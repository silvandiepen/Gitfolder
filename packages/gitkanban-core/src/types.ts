/**
 * GitKanban core types.
 *
 * These mirror the canonical board contract in `project-assets/Tasks/README.md`:
 * configuration (lanes, users, epics, priorities, types, tags) is defined at a
 * root level and overridden/extended per project, and cards are markdown files
 * with YAML frontmatter.
 */

export interface Lane {
  id: string
  name: string
  /** Directory name under the project (e.g. "1. To do"). Must exist on disk. */
  folder: string
  /** The card `status` value this lane holds. */
  status: string
  /** True for end lanes (Done, Won, Lost, …). */
  terminal?: boolean
}

export interface User {
  id: string
  name?: string
  kind?: 'human' | 'agent'
  github?: string
  role?: string
  [key: string]: unknown
}

export interface Epic {
  id: string
  name?: string
  description?: string
  /** Set when a root-level epic targets a single project. */
  project?: string
  [key: string]: unknown
}

export interface Priority {
  id: string
  name?: string
  description?: string
  [key: string]: unknown
}

/** Root board configuration (from `Tasks/README.md` frontmatter). */
export interface BoardConfig {
  lanes: Lane[]
  users: User[]
  epics: Epic[]
  priorities: Priority[]
  types: string[]
  tags: string[]
  [key: string]: unknown
}

/** Per-project configuration (from `Tasks/<project>/README.md` frontmatter). All optional. */
export interface ProjectConfig {
  project?: string
  lanes?: Lane[]
  users?: User[]
  epics?: Epic[]
  priorities?: Priority[]
  types?: string[]
  tags?: string[]
  [key: string]: unknown
}

/** The resolved configuration a board is actually rendered from. */
export interface EffectiveConfig {
  project?: string
  lanes: Lane[]
  users: User[]
  epics: Epic[]
  priorities: Priority[]
  types: string[]
  tags: string[]
}

/**
 * A parsed card. `frontmatter` holds every key verbatim (including keys this
 * library does not model) so writes round-trip without dropping agent/tool data.
 */
export interface ParsedCard {
  frontmatter: Record<string, unknown>
  body: string
}

/** The frontmatter fields GitKanban understands. Unknown keys are preserved on `ParsedCard`. */
export interface CardFields {
  id: string
  title: string
  project: string
  status: string
  priority?: string | null
  type?: string | null
  epic?: string | null
  assignee?: string | null
  order?: string | null
}
