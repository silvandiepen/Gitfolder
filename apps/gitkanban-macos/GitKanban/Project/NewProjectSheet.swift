import AppKit
import GitKit
import SwiftUI

/// A sheet for creating a new project: name, description, editable lanes,
/// priorities, and assignees. On Create it maps the fields into GitKit models
/// and asks the model to write + commit + push the project.
struct NewProjectSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var editing: BoardProject? = nil

    @State private var name = ""
    @State private var description = ""
    @State private var laneItems: [EditableItem] = NewProjectSheet.defaultLaneItems()
    @State private var priorityItems: [EditableItem] = NewProjectSheet.defaultPriorityItems()
    @State private var assigneeItems: [EditableItem] = []
    @State private var seeded = false
    @State private var isSaving = false
    /// In create mode with several repos connected, which repo the project lands in.
    @State private var targetRepoID: String?
    @State private var laneOrigins: [UUID: Lane] = [:]
    @State private var priorityNames: [UUID: String] = [:]
    @State private var userNames: [UUID: String] = [:]
    @State private var originalLanes: [Lane] = []
    @State private var originalUserIDs: Set<String> = []
    @State private var originalTypes: [String] = []
    @FocusState private var nameFocused: Bool

    private var isEditing: Bool { editing != nil }

    /// A stable-identity wrapper so the lists can reorder/delete without SwiftUI
    /// losing track of the row a text field is bound to.
    struct EditableItem: Identifiable {
        let id = UUID()
        var text: String
    }

    // MARK: Palettes

    private static let lanePalette: [Color] = [
        Color(red: 0.55, green: 0.36, blue: 0.96), // purple
        Color(red: 0.23, green: 0.51, blue: 0.96), // blue
        Color(red: 0.96, green: 0.62, blue: 0.09), // orange
        Color(red: 0.91, green: 0.70, blue: 0.05), // yellow
        Color(red: 0.13, green: 0.77, blue: 0.37), // green
        Color(red: 0.09, green: 0.64, blue: 0.72), // teal
        Color(red: 0.93, green: 0.28, blue: 0.60), // pink
    ]
    private static let priorityPalette: [Color] = [
        Color(red: 0.94, green: 0.27, blue: 0.27), // red
        Color(red: 0.96, green: 0.62, blue: 0.09), // orange
        Color(red: 0.91, green: 0.70, blue: 0.05), // yellow
        Color(red: 0.13, green: 0.77, blue: 0.37), // green
    ]
    private static let priorityLabels = ["Highest", "High", "Medium", "Low"]

    private func laneColor(_ i: Int) -> Color { Self.lanePalette[i % Self.lanePalette.count] }
    private func priorityColor(_ i: Int) -> Color { Self.priorityPalette[min(i, Self.priorityPalette.count - 1)] }
    private func priorityLabel(_ i: Int) -> String { i < Self.priorityLabels.count ? Self.priorityLabels[i] : "" }

    private static func defaultLaneItems() -> [EditableItem] {
        AppModel.defaultProjectLanes().map { EditableItem(text: $0.name) }
    }
    private static func defaultPriorityItems() -> [EditableItem] {
        AppModel.defaultPriorities().map { EditableItem(text: $0.id) }
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    projectSection
                    laneSection
                    prioritySection
                    assigneeSection
                }
                .padding(24)
            }
            footer
        }
        .frame(width: 620, height: 720)
        .background(.background)
        .onAppear(perform: seedIfNeeded)
    }

    private var header: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.35, green: 0.42, blue: 0.98), Color(red: 0.55, green: 0.36, blue: 0.96)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 46, height: 46)
                .overlay(Image(systemName: isEditing ? "gearshape.fill" : "folder.fill").font(.title3).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 2) {
                Text(isEditing ? "Project Settings" : "Create Project").font(.title2).fontWeight(.bold)
                Text(isEditing ? "Edit this project’s workflow and members." : "Set up your project and configure the workflow.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: Sections

    private var projectSection: some View {
        card {
            sectionTitle("Project")
            if !isEditing && model.connectedRepos.count > 1 {
                styledField {
                    Picker("Repository", selection: Binding(
                        get: { targetRepoID ?? model.activeRepo?.fullName ?? "" },
                        set: { targetRepoID = $0 }
                    )) {
                        ForEach(model.connectedRepos) { connected in
                            Text(connected.repo.fullName).tag(connected.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } focused: { false }
            }
            styledField {
                TextField("Project name", text: $name)
                    .textFieldStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .focused($nameFocused)
            } focused: { nameFocused }
            styledField {
                TextEditor(text: $description)
                    .textEditorStyle(.plain)
                    .frame(minHeight: 54)
                    .overlay(alignment: .topLeading) {
                        if description.isEmpty {
                            Text("Project description (optional)")
                                .foregroundStyle(.tertiary).padding(.vertical, 1).allowsHitTesting(false)
                        }
                    }
            } focused: { false }
        }
    }

    private var laneSection: some View {
        card {
            sectionHeader("Lanes (Workflow)",
                          addTitle: "Add lane",
                          onAdd: { laneItems.append(EditableItem(text: "")) },
                          onReset: { laneItems = Self.defaultLaneItems() })
            VStack(spacing: 8) {
                ForEach($laneItems) { $item in
                    let index = laneItems.firstIndex { $0.id == item.id } ?? 0
                    laneRow(item: $item, index: index)
                }
            }
        }
    }

    private func laneRow(item: Binding<EditableItem>, index: Int) -> some View {
        let color = laneColor(index)
        return HStack(spacing: 10) {
            Image(systemName: "circle.grid.2x3.fill")
                .font(.caption2).foregroundStyle(.tertiary)
            Circle().fill(color).frame(width: 9, height: 9)
            TextField("Lane name", text: item.text).textFieldStyle(.plain)
            Spacer(minLength: 8)
            if !item.wrappedValue.text.isEmpty {
                Text(item.wrappedValue.text)
                    .font(.caption).fontWeight(.medium)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .foregroundStyle(color)
                    .background(color.opacity(0.16), in: Capsule())
            }
            rowMenu(onUp: index > 0 ? { laneItems.swapAt(index, index - 1) } : nil,
                    onDown: index < laneItems.count - 1 ? { laneItems.swapAt(index, index + 1) } : nil,
                    onDelete: { laneItems.removeAll { $0.id == item.wrappedValue.id } })
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var prioritySection: some View {
        card {
            sectionHeader("Priorities",
                          addTitle: "Add priority",
                          onAdd: { priorityItems.append(EditableItem(text: "P\(priorityItems.count)")) },
                          onReset: { priorityItems = Self.defaultPriorityItems() })
            HStack(spacing: 10) {
                ForEach($priorityItems) { $item in
                    let index = priorityItems.firstIndex { $0.id == item.id } ?? 0
                    priorityCard(item: $item, index: index)
                }
            }
        }
    }

    private func priorityCard(item: Binding<EditableItem>, index: Int) -> some View {
        let color = priorityColor(index)
        return VStack(spacing: 6) {
            Image(systemName: "flag.fill").foregroundStyle(color)
            TextField("P\(index)", text: item.text)
                .textFieldStyle(.plain).multilineTextAlignment(.center)
                .font(.headline)
            Text(priorityLabel(index)).font(.caption2).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.quaternary, lineWidth: 1).allowsHitTesting(false))
        .contextMenu {
            Button("Delete", role: .destructive) { priorityItems.removeAll { $0.id == item.wrappedValue.id } }
        }
    }

    private var assigneeSection: some View {
        card {
            sectionHeader("Assignees (optional)",
                          addTitle: "Add assignee",
                          onAdd: { assigneeItems.append(EditableItem(text: "")) },
                          onReset: { assigneeItems = [] })
            if assigneeItems.isEmpty {
                Text("No assignees yet.").font(.callout).foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach($assigneeItems) { $item in
                        HStack(spacing: 10) {
                            Image(systemName: "person.circle.fill").foregroundStyle(.secondary)
                            TextField("username", text: $item.text).textFieldStyle(.plain)
                            Spacer(minLength: 8)
                            Button {
                                assigneeItems.removeAll { $0.id == item.id }
                            } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            if let error = model.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    Text(error).font(.caption).foregroundStyle(.red).lineLimit(3)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.top, 12)
            }
            HStack(spacing: 10) {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button {
                    save()
                } label: {
                    if isSaving || model.isCreatingProject {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(isEditing ? "Save Changes" : "Create Project")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(trimmedName.isEmpty || isSaving || model.isCreatingProject)
            }
            .padding(16)
        }
        .background(.regularMaterial)
    }

    // MARK: Reusable bits

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.quaternary.opacity(0.6), lineWidth: 1).allowsHitTesting(false))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.headline)
    }

    private func sectionHeader(_ title: String, addTitle: String, onAdd: @escaping () -> Void, onReset: @escaping () -> Void) -> some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            Button(action: onAdd) { Label(addTitle, systemImage: "plus") }
                .buttonStyle(.bordered).controlSize(.small)
            Button(action: onReset) { Label("Reset", systemImage: "arrow.counterclockwise") }
                .buttonStyle(.bordered).controlSize(.small)
        }
    }

    @ViewBuilder
    private func styledField<Content: View>(@ViewBuilder _ content: () -> Content, focused: () -> Bool) -> some View {
        content()
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(focused() ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary.opacity(0.7)),
                            lineWidth: focused() ? 2 : 1)
                    .allowsHitTesting(false)
            )
    }

    private func rowMenu(onUp: (() -> Void)?, onDown: (() -> Void)?, onDelete: @escaping () -> Void) -> some View {
        Menu {
            if let onUp { Button("Move up", action: onUp) }
            if let onDown { Button("Move down", action: onDown) }
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        } label: {
            Image(systemName: "ellipsis").foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
    }

    // MARK: Seeding (edit mode)

    /// In edit mode, fill the fields from the project's effective config once.
    /// Lanes keep their original identity in `laneOrigins` so a rename never
    /// renames the on-disk folder — only add/remove touch folders.
    private func seedIfNeeded() {
        guard !seeded else { return }
        seeded = true
        guard let editing else { return }

        let config: EffectiveConfig
        if model.selectedProject?.id == editing.id, let board = model.board {
            config = board.config
        } else {
            config = resolveEffectiveConfig(model.workspace?.rootConfig ?? BoardConfig(), editing.config)
        }

        name = config.project ?? editing.name
        description = ""

        originalLanes = config.lanes
        laneItems = config.lanes.map { lane in
            let item = EditableItem(text: lane.name)
            laneOrigins[item.id] = lane
            return item
        }
        priorityItems = config.priorities.map { p in
            let item = EditableItem(text: p.id)
            if let n = p.name { priorityNames[item.id] = n }
            return item
        }
        assigneeItems = config.users.map { u in
            let item = EditableItem(text: u.id)
            if let n = u.name { userNames[item.id] = n }
            return item
        }
        originalUserIDs = Set(config.users.map(\.id))
        originalTypes = config.types
    }

    // MARK: Save

    private func save() {
        guard !isSaving, !model.isCreatingProject else { return }
        if isEditing {
            saveEdits()
        } else {
            Task { await create() }
        }
    }

    private func create() async {
        // Land the project in the chosen repo (when several are connected).
        if let targetRepoID, targetRepoID != model.activeRepo?.fullName,
           let target = model.connectedRepos.first(where: { $0.id == targetRepoID }) {
            model.activate(target, project: nil)
        }
        let lanes = AppModel.lanes(fromNames: laneItems.map(\.text), terminalLast: true)
        let priorities = priorityItems
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { Priority(id: $0) }
        let users = assigneeItems
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { User(id: $0) }

        await model.createProject(
            name: trimmedName,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            lanes: lanes,
            priorities: priorities,
            users: users
        )
        if model.errorMessage == nil { dismiss() }
    }

    private func saveEdits() {
        guard let editing else { return }

        // New lane list: existing lanes keep folder/status/identity (rename = name only);
        // added lanes derive a folder from their name and get created on disk.
        var newLanes: [Lane] = []
        var createFolders: [String] = []
        for item in laneItems {
            let laneName = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !laneName.isEmpty else { continue }
            if let orig = laneOrigins[item.id] {
                newLanes.append(Lane(id: orig.id, name: laneName, folder: orig.folder,
                                     status: orig.status, terminal: orig.terminal, backlog: orig.backlog))
            } else {
                let status = laneSlug(laneName)
                let lane = Lane(id: status, name: laneName, folder: laneName, status: status)
                newLanes.append(lane)
                createFolders.append(lane.folder)
            }
        }
        guard !newLanes.isEmpty else {
            model.errorMessage = "A project needs at least one lane."
            return
        }

        // Removed lanes: originals no longer present. Ones holding tickets ask where
        // to move them; empty ones just have their folder removed.
        let keptIDs = Set(newLanes.map(\.id))
        var migrations: [(from: String, toFolder: String, toStatus: String)] = []
        for lane in originalLanes where !keptIDs.contains(lane.id) {
            let count = model.taskCount(inLaneStatus: lane.status)
            if count > 0 {
                guard let target = promptMoveTarget(from: lane, options: newLanes, count: count) else { return }
                migrations.append((from: lane.folder, toFolder: target.folder, toStatus: target.status))
            } else if let fallback = newLanes.first(where: { $0.folder != lane.folder }) {
                migrations.append((from: lane.folder, toFolder: fallback.folder, toStatus: fallback.status))
            }
        }

        let priorities = priorityItems.compactMap { item -> Priority? in
            let id = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return id.isEmpty ? nil : Priority(id: id, name: priorityNames[item.id])
        }
        let users = assigneeItems.compactMap { item -> User? in
            let id = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return id.isEmpty ? nil : User(id: id, name: userNames[item.id])
        }
        let unassign = originalUserIDs.subtracting(users.map(\.id))

        isSaving = true
        Task {
            await model.saveProjectSettings(
                project: editing,
                name: trimmedName,
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                lanes: newLanes,
                priorities: priorities,
                users: users,
                types: originalTypes,
                unassign: unassign,
                createFolders: createFolders,
                migrations: migrations
            )
            isSaving = false
            if model.errorMessage == nil { dismiss() }
        }
    }

    /// Ask which lane the tickets of a to-be-removed lane should move to.
    private func promptMoveTarget(from lane: Lane, options: [Lane], count: Int) -> Lane? {
        let alert = NSAlert()
        alert.messageText = "Remove lane “\(lane.name)”?"
        alert.informativeText = "\(count) task\(count == 1 ? "" : "s") are in this lane. Move them to:"
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 240, height: 26))
        for option in options { popup.addItem(withTitle: option.name) }
        alert.accessoryView = popup
        alert.addButton(withTitle: "Move & Remove")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let index = popup.indexOfSelectedItem
        return index >= 0 && index < options.count ? options[index] : options.first
    }

    private func laneSlug(_ s: String) -> String {
        let lowered = s.lowercased()
        let mapped = lowered.map { $0.isLetter || $0.isNumber ? $0 : "-" }
        return String(mapped).split(separator: "-").joined(separator: "-")
    }
}
