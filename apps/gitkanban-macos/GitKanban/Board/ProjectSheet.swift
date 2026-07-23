import GitKit
import GitKanbanKit
import SwiftUI

/// Create a project, or edit an existing project's settings — name, description, lanes,
/// priorities, members, types, and epics. Saving rewrites the project's README config.
struct ProjectSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    /// nil = create a new project; non-nil = edit that project's settings.
    var editing: BoardProject?
    /// When set, prefill the form from an auto-detected config (board setup flow).
    var prefill: DetectedBoardConfig?

    @State private var name = ""
    @State private var description = ""
    @State private var laneItems: [LaneItem] = ProjectSheet.defaultLanes()
    @State private var priorityItems: [TextItem] = ProjectSheet.defaultPriorities()
    @State private var memberItems: [TextItem] = []
    @State private var typeItems: [TextItem] = []
    @State private var epicItems: [EpicItem] = []
    @State private var seeded = false
    @State private var detecting = false

    private var isEditing: Bool { editing != nil }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    struct LaneItem: Identifiable { let id = UUID(); var name: String; var origin: Lane? }
    struct EpicItem: Identifiable { let id = UUID(); var name: String; var origin: Epic? }
    struct TextItem: Identifiable { let id = UUID(); var text: String }

    static func defaultLanes() -> [LaneItem] {
        AppModel.defaultProjectLanes().map { LaneItem(name: $0.name, origin: nil) }
    }
    static func defaultPriorities() -> [TextItem] {
        AppModel.defaultPriorities().map { TextItem(text: $0.id) }
    }

    static func laneColor(_ i: Int) -> Color {
        let palette: [Color] = [
            Color(red: 0.55, green: 0.36, blue: 0.96), Color(red: 0.23, green: 0.51, blue: 0.96),
            Color(red: 0.96, green: 0.62, blue: 0.09), Color(red: 0.91, green: 0.70, blue: 0.05),
            Color(red: 0.13, green: 0.77, blue: 0.37), Color(red: 0.09, green: 0.64, blue: 0.72),
        ]
        return palette[i % palette.count]
    }

    static func priorityColor(_ i: Int) -> Color {
        let ramp: [Color] = [
            Color(red: 0.90, green: 0.26, blue: 0.21), Color(red: 0.96, green: 0.55, blue: 0.09),
            Color(red: 0.23, green: 0.51, blue: 0.96), Color(red: 0.45, green: 0.50, blue: 0.58),
        ]
        return ramp[min(i, ramp.count - 1)]
    }

    @ViewBuilder private func deleteButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "minus.circle.fill").foregroundStyle(.red)
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Project") {
                    TextField("Name", text: $name)
                    TextField("Description (optional)", text: $description, axis: .vertical).lineLimit(1...4)
                }

                if isEditing {
                    Section {
                        Button { detect() } label: {
                            HStack {
                                Label("Detect from Folders", systemImage: "wand.and.stars")
                                Spacer()
                                if detecting { ProgressView().controlSize(.small) }
                            }
                        }
                        .disabled(detecting)
                    } footer: {
                        Text("Read the board's folders and cards to fill in lanes, priorities, types, members, and epics.")
                    }
                }

                Section("Lanes") {
                    ForEach($laneItems) { $item in
                        let index = laneItems.firstIndex { $0.id == item.id } ?? 0
                        HStack(spacing: 10) {
                            Circle().fill(Self.laneColor(index)).frame(width: 11, height: 11)
                            TextField("Lane name", text: $item.name)
                            deleteButton { laneItems.removeAll { $0.id == item.id } }
                        }
                    }
                    Button { laneItems.append(LaneItem(name: "", origin: nil)) } label: { Label("Add Lane", systemImage: "plus") }
                }

                Section("Priorities") {
                    ForEach($priorityItems) { $item in
                        let index = priorityItems.firstIndex { $0.id == item.id } ?? 0
                        HStack(spacing: 10) {
                            Image(systemName: "flag.fill").font(.caption).foregroundStyle(Self.priorityColor(index))
                            TextField("P0", text: $item.text)
                            deleteButton { priorityItems.removeAll { $0.id == item.id } }
                        }
                    }
                    Button { priorityItems.append(TextItem(text: "P\(priorityItems.count)")) } label: { Label("Add Priority", systemImage: "plus") }
                }

                Section("Members") {
                    ForEach($memberItems) { $item in
                        HStack {
                            TextField("username", text: $item.text).autocorrectionDisabled()
                            deleteButton { memberItems.removeAll { $0.id == item.id } }
                        }
                    }
                    Button { memberItems.append(TextItem(text: "")) } label: { Label("Add Member", systemImage: "plus") }
                }

                Section("Types") {
                    ForEach($typeItems) { $item in
                        HStack {
                            TextField("feature", text: $item.text)
                            deleteButton { typeItems.removeAll { $0.id == item.id } }
                        }
                    }
                    Button { typeItems.append(TextItem(text: "")) } label: { Label("Add Type", systemImage: "plus") }
                }

                Section("Epics") {
                    ForEach($epicItems) { $item in
                        HStack {
                            TextField("Epic name", text: $item.name)
                            deleteButton { epicItems.removeAll { $0.id == item.id } }
                        }
                    }
                    Button { epicItems.append(EpicItem(name: "", origin: nil)) } label: { Label("Add Epic", systemImage: "plus") }
                }

                if let error = model.errorMessage {
                    Section { Text(error).font(.callout).foregroundStyle(.red) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(prefill != nil ? "Set Up Board" : (isEditing ? "Project Settings" : "New Project"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") { Task { await save() } }
                        .disabled(trimmedName.isEmpty || model.isSaving)
                }
            }
            .onAppear(perform: seed)
        }
        .frame(minWidth: 520, minHeight: 560)
    }

    private func seed() {
        guard !seeded else { return }
        seeded = true
        guard let editing else { return }
        if let prefill {
            name = model.board?.config.project ?? editing.name
            laneItems = prefill.lanes.map { LaneItem(name: $0.name, origin: $0) }
            priorityItems = prefill.priorities.map { TextItem(text: $0.id) }
            memberItems = prefill.users.map { TextItem(text: $0.id) }
            typeItems = prefill.types.map { TextItem(text: $0) }
            epicItems = prefill.epics.map { EpicItem(name: $0.name ?? $0.id, origin: $0) }
            return
        }
        guard let config = model.board?.config else { return }
        name = config.project ?? editing.name
        laneItems = config.lanes.map { LaneItem(name: $0.name, origin: $0) }
        priorityItems = config.priorities.map { TextItem(text: $0.id) }
        memberItems = config.users.map { TextItem(text: $0.id) }
        typeItems = config.types.map { TextItem(text: $0) }
        epicItems = config.epics.map { EpicItem(name: $0.name ?? $0.id, origin: $0) }
    }

    private func detect() {
        guard let editing, !detecting else { return }
        detecting = true
        Task {
            let d = await model.detectConfig(for: editing)
            applyDetected(d)
            detecting = false
        }
    }

    private func applyDetected(_ d: DetectedBoardConfig) {
        if !d.lanes.isEmpty {
            laneItems = d.lanes.map { LaneItem(name: $0.name, origin: $0) }
        }
        for p in d.priorities where !priorityItems.contains(where: { $0.text.caseInsensitiveCompare(p.id) == .orderedSame }) {
            priorityItems.append(TextItem(text: p.id))
        }
        for u in d.users where !memberItems.contains(where: { $0.text.caseInsensitiveCompare(u.id) == .orderedSame }) {
            memberItems.append(TextItem(text: u.id))
        }
        for t in d.types where !typeItems.contains(where: { $0.text.caseInsensitiveCompare(t) == .orderedSame }) {
            typeItems.append(TextItem(text: t))
        }
        for e in d.epics {
            let label = e.name ?? e.id
            if !epicItems.contains(where: { ($0.origin?.id ?? "") == e.id || $0.name.caseInsensitiveCompare(label) == .orderedSame }) {
                epicItems.append(EpicItem(name: label, origin: e))
            }
        }
    }

    private func save() async {
        let lanes = buildLanes()
        let priorities = priorityItems.compactMap { t -> Priority? in
            let id = t.text.trimmingCharacters(in: .whitespaces); return id.isEmpty ? nil : Priority(id: id)
        }
        let users = memberItems.compactMap { t -> User? in
            let id = t.text.trimmingCharacters(in: .whitespaces); return id.isEmpty ? nil : User(id: id)
        }
        let types = typeItems.map { $0.text.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let epics = buildEpics()

        if let editing {
            await model.saveProjectSettings(project: editing, name: trimmedName, description: description,
                                            lanes: lanes, priorities: priorities, users: users, types: types, epics: epics)
        } else {
            await model.createProject(name: trimmedName, description: description,
                                      lanes: lanes, priorities: priorities, users: users, epics: epics)
        }
        if model.errorMessage == nil { dismiss() }
    }

    private func buildLanes() -> [Lane] {
        var used = Set(laneItems.compactMap { $0.origin?.id })
        var result: [Lane] = []
        for (index, item) in laneItems.enumerated() {
            let n = item.name.trimmingCharacters(in: .whitespaces)
            guard !n.isEmpty else { continue }
            if let origin = item.origin {
                result.append(Lane(id: origin.id, name: n, folder: origin.folder, status: origin.status,
                                   terminal: origin.terminal, backlog: origin.backlog))
            } else {
                var slug = n.lowercased().replacingOccurrences(of: " ", with: "-")
                var k = 2
                while used.contains(slug) { slug = "\(n.lowercased().replacingOccurrences(of: " ", with: "-"))-\(k)"; k += 1 }
                used.insert(slug)
                result.append(Lane(id: slug, name: n, folder: "\(index + 1). \(n)", status: slug))
            }
        }
        return result
    }

    private func buildEpics() -> [Epic] {
        var used = Set(epicItems.compactMap { $0.origin?.id })
        return epicItems.compactMap { item in
            let n = item.name.trimmingCharacters(in: .whitespaces)
            guard !n.isEmpty else { return nil }
            if let origin = item.origin { return Epic(id: origin.id, name: n) }
            var slug = n.lowercased().replacingOccurrences(of: " ", with: "-")
            var k = 2
            while used.contains(slug) { slug = "\(n.lowercased().replacingOccurrences(of: " ", with: "-"))-\(k)"; k += 1 }
            used.insert(slug)
            return Epic(id: slug, name: n)
        }
    }
}
