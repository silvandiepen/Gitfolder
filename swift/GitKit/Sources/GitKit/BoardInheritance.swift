import Foundation

/// Resolve a project's effective configuration by overlaying it on the root,
/// mirroring `@gitkit/gitkanban-core`'s `resolveEffectiveConfig`:
/// - Lanes **replace** (a non-empty project lane list wins; else inherit root).
/// - Vocabularies (users/epics/priorities/types/tags) **merge**; same id → project wins.
public func resolveEffectiveConfig(_ root: BoardConfig, _ project: ProjectConfig? = nil) -> EffectiveConfig {
    let lanes = (project?.lanes?.isEmpty == false) ? project!.lanes! : root.lanes
    return EffectiveConfig(
        project: project?.project,
        lanes: lanes,
        users: mergeById(root.users, project?.users, id: \User.id),
        epics: mergeById(root.epics, project?.epics, id: \Epic.id),
        priorities: mergeById(root.priorities, project?.priorities, id: \Priority.id),
        types: mergeStrings(root.types, project?.types),
        tags: mergeStrings(root.tags, project?.tags),
        fieldSource: project?.fieldSource ?? root.fieldSource
    )
}

private func mergeById<T>(_ root: [T], _ project: [T]?, id: KeyPath<T, String>) -> [T] {
    guard let project, !project.isEmpty else { return root }
    var order: [String] = root.map { $0[keyPath: id] }
    var byId: [String: T] = [:]
    for item in root { byId[item[keyPath: id]] = item }
    for item in project {
        let key = item[keyPath: id]
        if byId[key] == nil { order.append(key) }
        byId[key] = item
    }
    return order.compactMap { byId[$0] }
}

private func mergeStrings(_ root: [String], _ project: [String]?) -> [String] {
    guard let project, !project.isEmpty else { return root }
    var seen = Set(root)
    var result = root
    for value in project where !seen.contains(value) {
        seen.insert(value)
        result.append(value)
    }
    return result
}
