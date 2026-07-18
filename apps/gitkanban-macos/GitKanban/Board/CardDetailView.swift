import GitKit
import SwiftUI

/// A card's detail sheet with three modes:
/// - **Read** renders the markdown body and shows the fields as coloured chips.
/// - **Edit** exposes the fields as proper inputs/selects plus a description editor.
/// - **Code** is a raw editor over the whole `.md` file (frontmatter + body).
///
/// Saving from Edit rewrites the frontmatter (preserving unmodelled keys) and moves
/// the file if the lane changed; saving from Code writes the raw text verbatim. Both
/// commit + push to the live repo in the background.
struct CardDetailView: View {
    @Environment(AppModel.self) private var model
    let card: Card

    enum Mode: Hashable, CaseIterable { case read, edit, code }

    @State private var mode: Mode = .read
    @State private var isSaving = false

    // Raw editor (code mode).
    @State private var draft = ""

    // Structured editor (edit mode).
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
    private var accent: Color {
        PriorityColor.color(for: card.fields.priority, in: priorities)
            ?? LaneColor.forStatus(card.fields.status, in: lanes)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 560, minHeight: 500)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Capsule()
                .fill(accent)
                .frame(width: 4, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).lineLimit(2)
                metadata
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 8) {
                    modeSwitcher
                    if editable, mode != .read {
                        Divider().frame(height: 18)
                        saveButton
                    }
                    doneButton
                }
                if model.syncStatus != "Idle" && model.syncStatus != "Ready" {
                    Text(model.syncStatus)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .onChange(of: mode) { _, newValue in prepare(for: newValue) }
    }

    @ViewBuilder private var metadata: some View {
        HStack(spacing: 6) {
            if !card.fields.id.isEmpty {
                Text(card.fields.id)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
            if let priority = card.fields.priority,
               let color = PriorityColor.color(for: priority, in: priorities) {
                chip(priority, color: color)
            }
            if !card.fields.status.isEmpty {
                chip(statusName, color: LaneColor.forStatus(card.fields.status, in: lanes))
            }
            if let type = card.fields.type {
                chip(type, color: .secondary)
            }
            if let assignee = card.fields.assignee {
                Label("@\(assignee)", systemImage: "person.crop.circle")
                    .labelStyle(.titleOnly)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }

    private var statusName: String {
        lanes.first { $0.status == card.fields.status }?.name ?? card.fields.status
    }

    // MARK: Header controls

    private var modeSwitcher: some View {
        HStack(spacing: 2) {
            modeButton(.read, icon: "eye", help: "View")
            if editable {
                modeButton(.edit, icon: "slider.horizontal.3", help: "Edit fields")
                modeButton(.code, icon: "chevron.left.forwardslash.chevron.right", help: "Raw markdown")
            }
        }
        .padding(3)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
    }

    private func modeButton(_ target: Mode, icon: String, help: String) -> some View {
        Button {
            mode = target
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 26, height: 22)
                .foregroundStyle(mode == target ? Color.white : Color.secondary)
                .background {
                    if mode == target {
                        RoundedRectangle(cornerRadius: 6).fill(accent)
                    }
                }
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var saveButton: some View {
        Button(action: save) {
            if isSaving {
                ProgressView().controlSize(.small).frame(width: 20)
            } else {
                Image(systemName: "square.and.arrow.down.fill")
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
        .controlSize(.small)
        .keyboardShortcut("s", modifiers: .command)
        .disabled(isSaving)
        .help("Save changes (⌘S)")
    }

    private var doneButton: some View {
        Button { model.selectedCard = nil } label: {
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .semibold))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .keyboardShortcut(.cancelAction)
        .help("Done")
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        switch mode {
        case .read:
            MarkdownWebView(markdown: card.body)
        case .edit:
            editForm
        case .code:
            TextEditor(text: $draft)
                .font(.system(.body, design: .monospaced))
                .textEditorStyle(.plain)
                .padding(12)
                .background(Color(nsColor: .textBackgroundColor))
        }
    }

    private var editForm: some View {
        Form {
            Section("Task") {
                TextField("Title", text: $editTitle)
            }
            Section {
                Picker("Lane", selection: $editLaneID) {
                    ForEach(lanes) { Text($0.name).tag($0.id) }
                }
                if !priorities.isEmpty {
                    Picker("Priority", selection: $editPriority) {
                        Text("None").tag("")
                        ForEach(priorities, id: \.id) { Text($0.name ?? $0.id).tag($0.id) }
                    }
                }
                if !types.isEmpty {
                    Picker("Type", selection: $editType) {
                        Text("None").tag("")
                        ForEach(types, id: \.self) { Text($0).tag($0) }
                    }
                } else {
                    TextField("Type", text: $editType)
                }
                if users.isEmpty {
                    TextField("Assignee", text: $editAssignee)
                } else {
                    Picker("Assignee", selection: $editAssignee) {
                        Text("Unassigned").tag("")
                        ForEach(users, id: \.id) { Text($0.name ?? $0.id).tag($0.id) }
                    }
                }
                TextField("Order", text: $editOrder)
            }
            Section("Description") {
                TextEditor(text: $editBody)
                    .font(.body)
                    .frame(minHeight: 160)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Mode transitions + save

    /// Seed the editors when switching into a mode so each opens from current state.
    private func prepare(for newMode: Mode) {
        switch newMode {
        case .code:
            draft = model.rawText(for: card) ?? card.body
        case .edit:
            editTitle = card.fields.title
            editLaneID = lanes.first { $0.status == card.fields.status }?.id ?? lanes.first?.id ?? ""
            editPriority = card.fields.priority ?? ""
            editType = card.fields.type ?? ""
            editAssignee = card.fields.assignee ?? ""
            editOrder = card.fields.order ?? ""
            editBody = card.body.trimmingCharacters(in: .whitespacesAndNewlines)
        case .read:
            break
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        let currentMode = mode
        Task {
            switch currentMode {
            case .code:
                await model.saveCard(card, text: draft)
            case .edit:
                let lane = lanes.first { $0.id == editLaneID } ?? lanes.first
                let fields = CardFields(
                    id: card.fields.id,
                    title: editTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                    project: card.fields.project,
                    status: lane?.status ?? card.fields.status,
                    priority: nilIfEmpty(editPriority),
                    type: nilIfEmpty(editType),
                    epic: card.fields.epic,
                    assignee: nilIfEmpty(editAssignee),
                    order: nilIfEmpty(editOrder)
                )
                if let lane {
                    await model.updateCard(card, fields: fields, body: editBody, targetLane: lane)
                }
            case .read:
                break
            }
            isSaving = false
            if model.errorMessage == nil { mode = .read }
        }
    }

    private func nilIfEmpty(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
