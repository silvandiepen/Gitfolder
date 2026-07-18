import AppKit
import GitKit
import SwiftUI

/// A task's detail sheet. **View** shows the fields and a Nizel-rendered
/// description; **Edit** exposes editable fields and a description editor. The raw
/// markdown, GitHub link, history, export and delete live under the ⋯ menu.
struct CardDetailView: View {
    @Environment(AppModel.self) private var model
    let card: Card

    enum Mode: Hashable { case view, edit }

    @State private var mode: Mode = .view
    @State private var isSaving = false
    @State private var seeded = false
    @State private var showMarkdown = false
    @State private var showHistory = false
    @State private var editPreview = false

    // Editable state.
    @State private var editTitle = ""
    @State private var editLaneID = ""
    @State private var editPriority = ""
    @State private var editType = ""
    @State private var editAssignee = ""
    @State private var editOrder = ""
    @State private var editBody = ""

    private var editable: Bool { model.canEdit(card) }
    private var config: EffectiveConfig? { model.board?.config }
    private var lanes: [Lane] { config?.lanes ?? [] }
    private var priorities: [Priority] { config?.priorities ?? [] }
    private var users: [User] { config?.users ?? [] }
    private var types: [String] { config?.types ?? [] }

    private var title: String { card.fields.title.isEmpty ? card.fields.id : card.fields.title }
    private var currentLaneID: String { lanes.first { $0.status == card.fields.status }?.id ?? "" }

    private var isDirty: Bool {
        editTitle != card.fields.title
            || editLaneID != currentLaneID
            || editPriority != (card.fields.priority ?? "")
            || editType != (card.fields.type ?? "")
            || editAssignee != (card.fields.assignee ?? "")
            || editOrder != (card.fields.order ?? "")
            || editBody != card.body
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    fieldsCard
                    descriptionSection
                }
                .padding(20)
            }
            Divider()
            footer
        }
        .frame(width: 720, height: 660)
        .onAppear(perform: seedIfNeeded)
        .sheet(isPresented: $showMarkdown) { markdownSheet }
        .sheet(isPresented: $showHistory) { TaskHistorySheet(card: card).environment(model) }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.title2).fontWeight(.bold).lineLimit(2)
                metadata
            }
            Spacer(minLength: 12)
            HStack(spacing: 10) {
                if editable {
                    Picker("", selection: $mode) {
                        Text("View").tag(Mode.view)
                        Text("Edit").tag(Mode.edit)
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                }
                actionsMenu
                Button {
                    model.selectedCard = nil
                } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .help("Close")
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
    }

    @ViewBuilder private var metadata: some View {
        HStack(spacing: 6) {
            if !card.fields.id.isEmpty {
                Text(card.fields.id).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            if !card.fields.status.isEmpty {
                chip(laneName, color: LaneColor.forStatus(card.fields.status, in: lanes))
            }
            if let priority = card.fields.priority,
               let color = PriorityColor.color(for: priority, in: priorities) {
                chip(priority, color: color)
            }
            if let type = card.fields.type, !type.isEmpty {
                chip(type, color: .secondary)
            }
            if let assignee = card.fields.assignee, !assignee.isEmpty {
                Text("@\(assignee)").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var actionsMenu: some View {
        Menu {
            Button("Show Markdown") { showMarkdown = true }
            if model.githubURL(for: card) != nil {
                Button("Find on GitHub") {
                    if let url = model.githubURL(for: card) { NSWorkspace.shared.open(url) }
                }
            }
            Button("History…") { showHistory = true }
            Button("Export…") { export() }
            Divider()
            Button("Delete", role: .destructive) {
                Task { await model.deleteCard(cardID: card.fields.id); model.selectedCard = nil }
            }
        } label: {
            Image(systemName: "ellipsis").font(.system(size: 13, weight: .semibold))
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        .help("More actions")
    }

    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }

    private var laneName: String {
        lanes.first { $0.status == card.fields.status }?.name ?? card.fields.status
    }

    // MARK: Fields

    private var fieldsCard: some View {
        Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 14) {
            GridRow {
                field("Lane") { laneControl }
                field("Assignee") { assigneeControl }
            }
            GridRow {
                field("Priority") { priorityControl }
                field("Order") { orderControl }
            }
            GridRow {
                field("Type") { typeControl }
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
    }

    private func field<Control: View>(_ label: String, @ViewBuilder _ control: () -> Control) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            control().frame(minWidth: 190, alignment: .leading)
        }
    }

    @ViewBuilder private var laneControl: some View {
        if mode == .edit {
            Picker("", selection: $editLaneID) { ForEach(lanes) { Text($0.name).tag($0.id) } }
                .labelsHidden()
        } else {
            Text(laneName)
        }
    }

    @ViewBuilder private var assigneeControl: some View {
        if mode == .edit {
            if users.isEmpty {
                TextField("username", text: $editAssignee).textFieldStyle(.roundedBorder)
            } else {
                Picker("", selection: $editAssignee) {
                    Text("Unassigned").tag("")
                    ForEach(users, id: \.id) { Text($0.name ?? $0.id).tag($0.id) }
                }.labelsHidden()
            }
        } else {
            Text(card.fields.assignee.map { "@\($0)" } ?? "—")
                .foregroundStyle(card.fields.assignee == nil ? .secondary : .primary)
        }
    }

    @ViewBuilder private var priorityControl: some View {
        if mode == .edit {
            Picker("", selection: $editPriority) {
                Text("None").tag("")
                ForEach(priorities, id: \.id) { Text($0.name ?? $0.id).tag($0.id) }
            }.labelsHidden()
        } else {
            Text(card.fields.priority ?? "—")
                .foregroundStyle(card.fields.priority == nil ? .secondary : .primary)
        }
    }

    @ViewBuilder private var typeControl: some View {
        if mode == .edit {
            if types.isEmpty {
                TextField("type", text: $editType).textFieldStyle(.roundedBorder)
            } else {
                Picker("", selection: $editType) {
                    Text("None").tag("")
                    ForEach(types, id: \.self) { Text($0).tag($0) }
                }.labelsHidden()
            }
        } else {
            Text(card.fields.type ?? "—")
                .foregroundStyle(card.fields.type == nil ? .secondary : .primary)
        }
    }

    @ViewBuilder private var orderControl: some View {
        if mode == .edit {
            TextField("order", text: $editOrder).textFieldStyle(.roundedBorder)
        } else {
            Text(card.fields.order ?? "—")
                .foregroundStyle(card.fields.order == nil ? .secondary : .primary)
        }
    }

    // MARK: Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Description").font(.headline)
                Spacer()
                if mode == .edit {
                    Button { editPreview.toggle() } label: {
                        Image(systemName: editPreview ? "eye.fill" : "eye")
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .help(editPreview ? "Edit" : "Preview")
                }
            }
            if mode == .view || editPreview {
                MarkdownWebView(markdown: mode == .edit ? editBody : card.body)
                    .frame(minHeight: 240)
                    .background(.quaternary.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            } else {
                TextEditor(text: $editBody)
                    .font(.system(.body, design: .monospaced))
                    .textEditorStyle(.plain)
                    .frame(minHeight: 240)
                    .padding(10)
                    .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 12) {
            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.red).lineLimit(1)
            } else if !["Idle", "Ready", "Pushed"].contains(model.syncStatus) {
                Text(model.syncStatus).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if editable && mode == .edit {
                if isDirty {
                    HStack(spacing: 5) {
                        Circle().fill(.orange).frame(width: 6, height: 6)
                        Text("Unsaved changes").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Button { save() } label: {
                    if isSaving { ProgressView().controlSize(.small) }
                    else { Label("Save", systemImage: "checkmark") }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("s", modifiers: .command)
                .disabled(isSaving || !isDirty)
            }
        }
        .padding(14)
    }

    // MARK: Markdown sheet

    private var markdownSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Markdown").font(.headline)
                Spacer()
                Button("Copy") {
                    let raw = model.rawText(for: card) ?? card.body
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(raw, forType: .string)
                }
                Button("Done") { showMarkdown = false }.keyboardShortcut(.cancelAction)
            }
            .padding(14)
            Divider()
            ScrollView {
                Text(model.rawText(for: card) ?? card.body)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            }
        }
        .frame(width: 620, height: 560)
    }

    // MARK: Actions

    private func seedIfNeeded() {
        guard !seeded else { return }
        seeded = true
        editTitle = card.fields.title
        editLaneID = currentLaneID.isEmpty ? (lanes.first?.id ?? "") : currentLaneID
        editPriority = card.fields.priority ?? ""
        editType = card.fields.type ?? ""
        editAssignee = card.fields.assignee ?? ""
        editOrder = card.fields.order ?? ""
        editBody = card.body
    }

    private func save() {
        guard !isSaving, let lane = lanes.first(where: { $0.id == editLaneID }) ?? lanes.first else { return }
        isSaving = true
        let fields = CardFields(
            id: card.fields.id,
            title: editTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            project: card.fields.project,
            status: lane.status,
            priority: nilIfEmpty(editPriority),
            type: nilIfEmpty(editType),
            epic: card.fields.epic,
            assignee: nilIfEmpty(editAssignee),
            order: nilIfEmpty(editOrder)
        )
        Task {
            await model.updateCard(card, fields: fields, body: editBody, targetLane: lane)
            isSaving = false
            if model.errorMessage == nil { model.selectedCard = nil }
        }
    }

    private func export() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = card.fileName ?? "\(card.fields.id).md"
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            try? (model.rawText(for: card) ?? card.body).write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func nilIfEmpty(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
