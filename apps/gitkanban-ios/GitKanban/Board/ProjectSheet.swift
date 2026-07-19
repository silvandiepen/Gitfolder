import GitKit
import SwiftUI

/// Create a project, or edit an existing project's settings — name, description, lanes,
/// priorities, members, types, and epics. Saving rewrites the project's README config.
struct ProjectSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    /// nil = create a new project; non-nil = edit that project's settings.
    var editing: BoardProject?

    @State private var name = ""
    @State private var description = ""
    @State private var laneItems: [LaneItem] = ProjectSheet.defaultLanes()
    @State private var priorityItems: [TextItem] = ProjectSheet.defaultPriorities()
    @State private var memberItems: [TextItem] = []
    @State private var typeItems: [TextItem] = []
    @State private var epicItems: [EpicItem] = []
    @State private var seeded = false

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

    /// Lane colour by position (matches the board's palette).
    static func laneColor(_ i: Int) -> Color {
        let palette: [Color] = [
            Color(red: 0.55, green: 0.36, blue: 0.96), Color(red: 0.23, green: 0.51, blue: 0.96),
            Color(red: 0.96, green: 0.62, blue: 0.09), Color(red: 0.91, green: 0.70, blue: 0.05),
            Color(red: 0.13, green: 0.77, blue: 0.37), Color(red: 0.09, green: 0.64, blue: 0.72),
        ]
        return palette[i % palette.count]
    }

    /// Priority colour by rank (highest → lowest).
    static func priorityColor(_ i: Int) -> Color {
        let ramp: [Color] = [
            Color(red: 0.90, green: 0.26, blue: 0.21), Color(red: 0.96, green: 0.55, blue: 0.09),
            Color(red: 0.23, green: 0.51, blue: 0.96), Color(red: 0.45, green: 0.50, blue: 0.58),
        ]
        return ramp[min(i, ramp.count - 1)]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Project") {
                    TextField("Name", text: $name)
                    TextField("Description (optional)", text: $description, axis: .vertical).lineLimit(1...4)
                }

                Section {
                    ForEach($laneItems) { $item in
                        let index = laneItems.firstIndex { $0.id == item.id } ?? 0
                        HStack(spacing: 10) {
                            Circle().fill(Self.laneColor(index)).frame(width: 11, height: 11)
                            TextField("Lane name", text: $item.name)
                        }
                    }
                    .onDelete { laneItems.remove(atOffsets: $0) }
                    .onMove { laneItems.move(fromOffsets: $0, toOffset: $1) }
                    Button { laneItems.append(LaneItem(name: "", origin: nil)) } label: { Label("Add Lane", systemImage: "plus") }
                } header: {
                    Text("Lanes")
                } footer: {
                    Text("Drag to reorder (Edit); the first lanes are the start of the workflow.")
                }

                Section {
                    ForEach($priorityItems) { $item in
                        let index = priorityItems.firstIndex { $0.id == item.id } ?? 0
                        HStack(spacing: 10) {
                            Image(systemName: "flag.fill").font(.caption).foregroundStyle(Self.priorityColor(index))
                            TextField("P0", text: $item.text).textInputAutocapitalization(.characters)
                        }
                    }
                    .onDelete { priorityItems.remove(atOffsets: $0) }
                    Button { priorityItems.append(TextItem(text: "P\(priorityItems.count)")) } label: { Label("Add Priority", systemImage: "plus") }
                } header: {
                    Text("Priorities")
                } footer: {
                    Text("Ordered highest to lowest.")
                }

                Section("Members") {
                    ForEach($memberItems) { $item in
                        TextField("username", text: $item.text).textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                    .onDelete { memberItems.remove(atOffsets: $0) }
                    Button { memberItems.append(TextItem(text: "")) } label: { Label("Add Member", systemImage: "plus") }
                }

                Section("Types") {
                    ForEach($typeItems) { $item in
                        TextField("feature", text: $item.text).textInputAutocapitalization(.never)
                    }
                    .onDelete { typeItems.remove(atOffsets: $0) }
                    Button { typeItems.append(TextItem(text: "")) } label: { Label("Add Type", systemImage: "plus") }
                }

                Section("Epics") {
                    ForEach($epicItems) { $item in TextField("Epic name", text: $item.name) }
                        .onDelete { epicItems.remove(atOffsets: $0) }
                    Button { epicItems.append(EpicItem(name: "", origin: nil)) } label: { Label("Add Epic", systemImage: "plus") }
                }

                if let error = model.errorMessage {
                    Section { Text(error).font(.callout).foregroundStyle(.red) }
                }
            }
            .navigationTitle(isEditing ? "Project Settings" : "New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") { Task { await save() } }
                        .disabled(trimmedName.isEmpty || model.isSaving)
                }
            }
            .onAppear(perform: seed)
        }
    }

    private func seed() {
        guard !seeded else { return }
        seeded = true
        guard editing != nil, let config = model.board?.config else { return }
        name = config.project ?? editing?.name ?? ""
        laneItems = config.lanes.map { LaneItem(name: $0.name, origin: $0) }
        priorityItems = config.priorities.map { TextItem(text: $0.id) }
        memberItems = config.users.map { TextItem(text: $0.id) }
        typeItems = config.types.map { TextItem(text: $0) }
        epicItems = config.epics.map { EpicItem(name: $0.name ?? $0.id, origin: $0) }
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

