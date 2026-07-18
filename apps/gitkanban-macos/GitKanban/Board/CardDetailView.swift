import AppKit
import GitKit
import SwiftUI

/// A task's detail sheet. The fields (Lane/Assignee/Priority/Type) are always
/// editable selects; only the description toggles between a Nizel-rendered preview
/// and an editor. Raw markdown, GitHub link, history, export and delete live under
/// the ⋯ menu. Save persists everything (commit + push in the background).
struct CardDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let card: Card

    @State private var isSaving = false
    @State private var seeded = false
    @State private var showMarkdown = false
    @State private var showHistory = false
    @State private var editingDesc = false

    // Editable state.
    @State private var editTitle = ""
    @State private var editLaneID = ""
    @State private var editPriority = ""
    @State private var editType = ""
    @State private var editAssignee = ""
    @State private var editEpic = ""
    @State private var editBody = ""

    private var editable: Bool { model.canEdit(card) }
    private var config: EffectiveConfig? { model.board?.config }
    private var lanes: [Lane] { config?.lanes ?? [] }
    private var priorities: [Priority] { config?.priorities ?? [] }
    private var users: [User] { config?.users ?? [] }
    private var types: [String] { config?.types ?? [] }
    private var epics: [Epic] { config?.epics ?? [] }

    private var title: String { card.fields.title.isEmpty ? card.fields.id : card.fields.title }
    private var currentLaneID: String { lanes.first { $0.status == card.fields.status }?.id ?? "" }

    private var isDirty: Bool {
        editTitle != card.fields.title
            || editLaneID != currentLaneID
            || editPriority != (card.fields.priority ?? "")
            || editType != (card.fields.type ?? "")
            || editAssignee != (card.fields.assignee ?? "")
            || editEpic != (card.fields.epic ?? "")
            || editBody != card.body
    }

    private func laneColor(_ id: String) -> Color {
        guard let index = lanes.firstIndex(where: { $0.id == id }) else { return .gray }
        return LaneColor.at(index)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            fieldsCard.padding(16)
            Divider()
            descriptionSection.frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            footer
        }
        .frame(minWidth: 560, minHeight: 460)
        .toolbar { ToolbarItem(placement: .primaryAction) { actionsMenu } }
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
            if let epic = card.fields.epic, !epic.isEmpty {
                chip(epics.first { $0.id == epic }?.name ?? epic, color: .purple)
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
                Task { await model.deleteCard(cardID: card.fields.id) }
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

    // MARK: Fields (always editable)

    private var fieldsCard: some View {
        Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 14) {
            GridRow {
                field("Lane") { laneControl }
                field("Assignee") { assigneeControl }
            }
            GridRow {
                field("Priority") { priorityControl }
                field("Type") { typeControl }
            }
            if !epics.isEmpty {
                GridRow {
                    field("Epic") { epicControl }
                    Color.clear.frame(height: 0)
                }
            }
        }
        .disabled(!editable)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
    }

    private func field<Control: View>(_ label: String, @ViewBuilder _ control: () -> Control) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            control().frame(minWidth: 200, alignment: .leading)
        }
    }

    /// A consistently-styled select: a pill showing a colour dot or icon + the current
    /// value + a chevron, opening a native menu of options.
    private func selectPill<Menu: View>(
        value: String,
        placeholder: String,
        dot: Color? = nil,
        icon: String? = nil,
        @ViewBuilder menu: () -> Menu
    ) -> some View {
        SwiftUI.Menu {
            menu()
        } label: {
            HStack(spacing: 7) {
                if let dot {
                    Circle().fill(dot).frame(width: 9, height: 9)
                } else if let icon {
                    Image(systemName: icon).font(.caption).foregroundStyle(.secondary).frame(width: 12)
                }
                Text(value.isEmpty ? placeholder : value)
                    .foregroundStyle(value.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                    .lineLimit(1)
                Spacer(minLength: 6)
                Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(.quaternary.opacity(0.7), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden)
    }

    private var selectedLaneName: String {
        lanes.first { $0.id == editLaneID }?.name ?? ""
    }

    private var laneControl: some View {
        selectPill(value: selectedLaneName, placeholder: "Lane", dot: laneColor(editLaneID)) {
            ForEach(Array(lanes.enumerated()), id: \.element.id) { index, lane in
                Button {
                    editLaneID = lane.id
                } label: {
                    Label(lane.name, systemImage: editLaneID == lane.id ? "checkmark" : "circle.fill")
                        .foregroundStyle(editLaneID == lane.id ? AnyShapeStyle(.primary) : AnyShapeStyle(LaneColor.at(index)))
                }
            }
        }
    }

    private var selectedPriorityName: String {
        editPriority.isEmpty ? "" : (priorities.first { $0.id == editPriority }?.name ?? editPriority)
    }

    private var priorityControl: some View {
        selectPill(
            value: selectedPriorityName,
            placeholder: "None",
            dot: editPriority.isEmpty ? nil : (PriorityColor.color(for: editPriority, in: priorities) ?? .gray)
        ) {
            Button {
                editPriority = ""
            } label: { Label("None", systemImage: editPriority.isEmpty ? "checkmark" : "circle") }
            Divider()
            ForEach(priorities, id: \.id) { priority in
                Button {
                    editPriority = priority.id
                } label: {
                    Label(priority.name ?? priority.id,
                          systemImage: editPriority == priority.id ? "checkmark" : "flag.fill")
                        .foregroundStyle(editPriority == priority.id ? AnyShapeStyle(.primary)
                            : AnyShapeStyle(PriorityColor.color(for: priority.id, in: priorities) ?? .gray))
                }
            }
        }
    }

    private var selectedAssigneeName: String {
        editAssignee.isEmpty ? "" : (users.first { $0.id == editAssignee }?.name ?? editAssignee)
    }

    @ViewBuilder private var assigneeControl: some View {
        if users.isEmpty {
            TextField("username", text: $editAssignee).textFieldStyle(.roundedBorder)
        } else {
            selectPill(value: selectedAssigneeName, placeholder: "Unassigned", icon: "person.crop.circle") {
                Button {
                    editAssignee = ""
                } label: { Label("Unassigned", systemImage: editAssignee.isEmpty ? "checkmark" : "person.crop.circle.badge.xmark") }
                Divider()
                ForEach(users, id: \.id) { user in
                    Button {
                        editAssignee = user.id
                    } label: {
                        Label(user.name ?? user.id,
                              systemImage: editAssignee == user.id ? "checkmark" : "person.crop.circle")
                    }
                }
            }
        }
    }

    /// A select of the project's types that also allows a custom value.
    private var typeControl: some View {
        selectPill(value: editType, placeholder: "None", icon: editType.isEmpty ? "tag" : TypeIcon.name(editType)) {
            ForEach(types, id: \.self) { type in
                Button {
                    editType = type
                } label: { Label(type, systemImage: editType == type ? "checkmark" : TypeIcon.name(type)) }
            }
            if !types.isEmpty { Divider() }
            Button("Custom…") { promptCustomType() }
            if !editType.isEmpty { Button("Clear") { editType = "" } }
        }
    }

    private var selectedEpicName: String {
        editEpic.isEmpty ? "" : (epics.first { $0.id == editEpic }?.name ?? editEpic)
    }

    private var epicControl: some View {
        selectPill(value: selectedEpicName, placeholder: "None", icon: "square.stack.3d.up") {
            Button {
                editEpic = ""
            } label: { Label("None", systemImage: editEpic.isEmpty ? "checkmark" : "circle") }
            Divider()
            ForEach(epics, id: \.id) { epic in
                Button {
                    editEpic = epic.id
                } label: {
                    Label(epic.name ?? epic.id,
                          systemImage: editEpic == epic.id ? "checkmark" : "square.stack.3d.up")
                }
            }
        }
    }

    private func promptCustomType() {
        let alert = NSAlert()
        alert.messageText = "Custom Type"
        alert.informativeText = "Enter a type for this task."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.stringValue = editType
        alert.accessoryView = field
        alert.addButton(withTitle: "Set")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            editType = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    // MARK: Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Description").font(.headline)
                Spacer()
                if editable {
                    Button { editingDesc.toggle() } label: {
                        Label(editingDesc ? "Preview" : "Edit",
                              systemImage: editingDesc ? "eye" : "square.and.pencil")
                            .font(.caption)
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)

            if editingDesc {
                TextEditor(text: $editBody)
                    .font(.system(.body, design: .monospaced))
                    .textEditorStyle(.plain)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                MarkdownWebView(markdown: editBody)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            if editable {
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
        editEpic = card.fields.epic ?? ""
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
            epic: nilIfEmpty(editEpic),
            assignee: nilIfEmpty(editAssignee),
            order: card.fields.order
        )
        Task {
            await model.updateCard(card, fields: fields, body: editBody, targetLane: lane)
            isSaving = false
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
