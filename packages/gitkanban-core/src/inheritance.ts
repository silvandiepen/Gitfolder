import type { BoardConfig, EffectiveConfig, Epic, Priority, ProjectConfig, User } from './types.js'

interface Identified {
  id: string
}

/**
 * Merge two vocabularies by `id`: root entries first, then project entries.
 * When a project entry shares an id with a root entry, the project entry wins
 * (in place, preserving order).
 */
function mergeById<T extends Identified>(root: T[], project: T[] | undefined): T[] {
  if (!project || project.length === 0) return [...root]
  const byId = new Map<string, T>()
  for (const item of root) byId.set(item.id, item)
  const order: string[] = root.map((item) => item.id)
  for (const item of project) {
    if (!byId.has(item.id)) order.push(item.id)
    byId.set(item.id, item)
  }
  return order.map((id) => byId.get(id) as T)
}

/** Merge two string lists as an ordered set (root order preserved, new project values appended). */
function mergeStrings(root: string[], project: string[] | undefined): string[] {
  if (!project || project.length === 0) return [...root]
  const seen = new Set(root)
  const result = [...root]
  for (const value of project) {
    if (!seen.has(value)) {
      seen.add(value)
      result.push(value)
    }
  }
  return result
}

/**
 * Resolve the effective configuration for a project by overlaying its config on
 * the root board config, per the contract's two rules:
 *
 * - **Lanes → replace.** A non-empty project `lanes` list fully replaces the root
 *   lanes (a custom workflow). Empty/absent inherits the root lanes.
 * - **Vocabularies (users, epics, priorities, types, tags) → merge.** Project
 *   entries extend root; same id → project wins.
 */
export function resolveEffectiveConfig(root: BoardConfig, project?: ProjectConfig): EffectiveConfig {
  const lanes = project?.lanes && project.lanes.length > 0 ? project.lanes : root.lanes
  return {
    project: project?.project,
    lanes: [...lanes],
    users: mergeById<User>(root.users, project?.users),
    epics: mergeById<Epic>(root.epics, project?.epics),
    priorities: mergeById<Priority>(root.priorities, project?.priorities),
    types: mergeStrings(root.types, project?.types),
    tags: mergeStrings(root.tags, project?.tags),
  }
}
