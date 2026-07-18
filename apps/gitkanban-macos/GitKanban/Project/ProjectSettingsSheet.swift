import AppKit
import GitKit
import SwiftUI

/// Editable project settings: name/description, lanes (rename + reorder), priorities,
/// assignees and types. Saving rewrites the project's README config and, when a
/// member with tasks is removed, offers to unassign those tasks.
struct ProjectSettingsSheet: View {
    @Environment(AppModel.self) private var model
    let project: BoardProject

    struct Row: Identifiable { let id = UUID(); var a: String; var b: String }

    @State private var seeded = false
    @State private var isSaving = false
    @State private var name = ""
    @State private var descriptionText = ""
    @State private var laneList: [Lane] = []
    @State private var priorityRows: [Row] = []
    @State private var userRows: [Row] = []
    @State private var typeRows: [Row] = []
    @State private var originalUserIDs: Set<String> = []

    private var config: EffectiveConfig {
        if let board = model.board, model.selectedProject?.id == project.id { return board.config }
        return resolveEffectiveConfig(model.workspace?.rootConfig ?? BoardConfig(), project.config)
    }

    private var priorities: [Priority] {
        priorityRows.compactMap { row in
            let id = row.a.trimmingCharacters(in: .whitespaces)
            return id.isEmpty ? nil : Priority(id: id, name: nilIfEmpty(row.b))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "gearshape").font(.title2).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Project Settings").font(.headline)
                    Text(project.name).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(16)
            Divider()

            Form {
                Section("Project") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $descriptionText, axis: .vertical).lineLimit(1...3)
                }

                Section {
                    ForEach($laneList) { $lane in
                        HStack(spacing: 8) {
                            Circle().fill(laneColor(lane.id)).frame(width: 9, height: 9)
                            TextField("Lane name", text: $lane.name)
                            Spacer()
                            Text(lane.status).font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                    .onMove { laneList.move(fromOffsets: $0, toOffset: $1) }
                } header: {
                    Text("Lanes")
                } footer: {
                    Text("Rename and reorder lanes. Adding/removing lanes (which moves task files) is coming next.")
                        .font(.caption2).foregroundStyle(.tertiary)
                }

                editableSection("Priorities", rows: $priorityRows,
                                placeholderA: "P0", placeholderB: "Highest",
                                colorFor: { PriorityColor.color(for: $0.a, in: priorities) })

                editableSection("Assignees", rows: $userRows,
                                placeholderA: "username", placeholderB: "Full name",
                                colorFor: { _ in nil })

                Section {
                    ForEach($typeRows) { $row in
                        HStack {
                            TextField("type", text: $row.a)
                            Spacer()
                            Button {
                                typeRows.removeAll { $0.id == row.id }
                            } label: { Image(systemName: "minus.circle.fill").foregroundStyle(.tertiary) }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    HStack {
                        Text("Types")
                        Spacer()
                        Button { typeRows.append(Row(a: "", b: "")) } label: {
                            Image(systemName: "plus")
                        }.buttonStyle(.borderless)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Button("Reveal in Finder") { model.revealInFinder(project) }
                Spacer()
                Button("Cancel") { model.settingsProject = nil }.keyboardShortcut(.cancelAction)
                Button {
                    save()
                } label: {
                    if isSaving { ProgressView().controlSize(.small) } else { Text("Save") }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(16)
        }
        .frame(width: 520, height: 640)
        .onAppear(perform: seedIfNeeded)
    }

    private func editableSection(_ title: String, rows: Binding<[Row]>,
                                 placeholderA: String, placeholderB: String,
                                 colorFor: @escaping (Row) -> Color?) -> some View {
        Section {
            ForEach(rows) { $row in
                HStack(spacing: 8) {
                    if let color = colorFor(row) {
                        Circle().fill(color).frame(width: 9, height: 9)
                    }
                    TextField(placeholderA, text: $row.a).frame(width: 110)
                    TextField(placeholderB, text: $row.b)
                    Button {
                        rows.wrappedValue.removeAll { $0.id == row.id }
                    } label: { Image(systemName: "minus.circle.fill").foregroundStyle(.tertiary) }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            HStack {
                Text(title)
                Spacer()
                Button { rows.wrappedValue.append(Row(a: "", b: "")) } label: {
                    Image(systemName: "plus")
                }.buttonStyle(.borderless)
            }
        }
    }

    private func laneColor(_ id: String) -> Color {
        guard let index = laneList.firstIndex(where: { $0.id == id }) else { return .gray }
        return LaneColor.at(index)
    }

    private func seedIfNeeded() {
        guard !seeded else { return }
        seeded = true
        name = config.project ?? project.name
        descriptionText = ""
        laneList = config.lanes
        priorityRows = config.priorities.map { Row(a: $0.id, b: $0.name ?? "") }
        userRows = config.users.map { Row(a: $0.id, b: $0.name ?? "") }
        typeRows = config.types.map { Row(a: $0, b: "") }
        originalUserIDs = Set(config.users.map(\.id))
    }

    private func save() {
        let users = userRows.compactMap { row -> User? in
            let id = row.a.trimmingCharacters(in: .whitespaces)
            return id.isEmpty ? nil : User(id: id, name: nilIfEmpty(row.b))
        }
        let types = typeRows.map { $0.a.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let removed = originalUserIDs.subtracting(users.map(\.id))
        let affected = removed.reduce(0) { $0 + model.taskCount(assignedTo: $1) }

        if affected > 0 {
            let alert = NSAlert()
            alert.messageText = "Remove \(removed.count) member\(removed.count == 1 ? "" : "s")?"
            alert.informativeText = "\(affected) task\(affected == 1 ? " is" : "s are") assigned to them. Unassign those tasks?"
            alert.addButton(withTitle: "Unassign & Save")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        isSaving = true
        Task {
            await model.saveProjectSettings(
                project: project,
                name: name.trimmingCharacters(in: .whitespaces),
                description: descriptionText.trimmingCharacters(in: .whitespaces),
                lanes: laneList,
                priorities: priorities,
                users: users,
                types: types,
                unassign: affected > 0 ? removed : []
            )
            isSaving = false
            if model.errorMessage == nil { model.settingsProject = nil }
        }
    }

    private func nilIfEmpty(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? nil : t
    }
}
