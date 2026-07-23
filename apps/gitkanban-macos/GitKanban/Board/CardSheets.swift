import AppKit
import GitKanbanKit
import GitKit
import SwiftUI
import UniformTypeIdentifiers

/// A card's detail: opens in a read view with the description rendered as Markdown,
/// with an Edit button that flips to an editable form. Saving commits over the
/// provider API (git-pont) and reloads the board.
struct CardDetailSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let card: Card

    @State private var editing = false
    @State private var confirmDelete = false
    @State private var attachments: [BoardFileEntry] = []
    @State private var showImporter = false

    // Editable state.
    @State private var title = ""
    @State private var laneID = ""
    @State private var priority = ""
    @State private var type = ""
    @State private var assignee = ""
    @State private var epic = ""
    @State private var body_ = ""
    @State private var seeded = false

    private var config: EffectiveConfig? { model.board?.config }
    private var lanes: [Lane] { config?.lanes ?? [] }
    private var priorities: [Priority] { config?.priorities ?? [] }
    private var users: [User] { config?.users ?? [] }
    private var types: [String] { config?.types ?? [] }
    private var epics: [Epic] { config?.epics ?? [] }

    private var laneForStatus: Lane? { lanes.first { $0.status == card.fields.status } }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(card.fields.id.isEmpty ? "Task" : card.fields.id)
                .confirmationDialog("Delete this task?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Delete", role: .destructive) { Task { await model.deleteCard(card); dismiss() } }
                }
                .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
                    handleImport(result)
                }
                .task { await loadAttachments() }
        }
        .frame(minWidth: 560, minHeight: 520)
        .onAppear(perform: seed)
    }

    private func loadAttachments() async { attachments = await model.attachments(for: card) }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        let name = url.lastPathComponent
        Task { if await model.attachFile(to: card, data: data, filename: name) { await loadAttachments() } }
    }

    private func saveAttachment(_ entry: BoardFileEntry) async {
        guard let data = await model.readAttachment(path: entry.path) else { return }
        Platform.save(data: data, suggestedName: entry.name)
    }

    @ViewBuilder private var content: some View {
        if editing {
            editForm.toolbar { editToolbar }
        } else {
            readView.toolbar { readToolbar }
        }
    }

    // MARK: Read

    private var readView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(card.fields.title.isEmpty ? card.fields.id : card.fields.title)
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)

                metadata

                Divider()

                if card.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("No description.").font(.body).foregroundStyle(.secondary)
                } else {
                    MarkdownWebView(markdown: card.body).frame(minHeight: 180)
                }

                Divider()
                attachmentsSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Attachments").font(.headline)
                Spacer()
                Button { showImporter = true } label: { Label("Add", systemImage: "paperclip").font(.caption) }
            }
            if attachments.isEmpty {
                Text("No attachments.").font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(attachments, id: \.path) { entry in
                    AttachmentRow(entry: entry)
                        .contentShape(Rectangle())
                        .onTapGesture { Task { await saveAttachment(entry) } }
                        .contextMenu {
                            Button("Save…", systemImage: "square.and.arrow.down") { Task { await saveAttachment(entry) } }
                            Button("Remove", systemImage: "trash", role: .destructive) {
                                Task { await model.deleteAttachment(path: entry.path); await loadAttachments() }
                            }
                        }
                }
            }
        }
    }

    @ViewBuilder private var metadata: some View {
        let cfg = config ?? EffectiveConfig()
        HStack(spacing: 6) {
            if let lane = laneForStatus { chip(lane.name, color: laneColor(lane, cfg)) }
            if let p = card.fields.priority, let color = PriorityPalette.color(p, priorities) { chip(p, color: color) }
            if let t = card.fields.type { chip(t, color: .secondary) }
            if let e = card.fields.epic { chip(epics.first { $0.id == e }?.name ?? e, color: .purple) }
            if let a = card.fields.assignee {
                Label("@\(a)", systemImage: "person.crop.circle").labelStyle(.titleOnly)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }

    @ToolbarContentBuilder private var readToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
        ToolbarItemGroup(placement: .primaryAction) {
            Button("Edit") { editing = true }
            Menu {
                Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
            } label: { Image(systemName: "ellipsis.circle") }
        }
    }

    // MARK: Edit

    private var editForm: some View {
        Form {
            Section("Task") { TextField("Title", text: $title) }
            Section {
                Picker("Lane", selection: $laneID) {
                    ForEach(lanes) { Text($0.name).tag($0.id) }
                }
                if !priorities.isEmpty {
                    Picker("Priority", selection: $priority) {
                        Text("None").tag("")
                        ForEach(priorities, id: \.id) { Text($0.name ?? $0.id).tag($0.id) }
                    }
                }
                if types.isEmpty {
                    TextField("Type", text: $type)
                } else {
                    Picker("Type", selection: $type) {
                        Text("None").tag("")
                        ForEach(types, id: \.self) { Text($0).tag($0) }
                    }
                }
                if users.isEmpty {
                    TextField("Assignee", text: $assignee)
                } else {
                    Picker("Assignee", selection: $assignee) {
                        Text("Unassigned").tag("")
                        ForEach(users, id: \.id) { Text($0.name ?? $0.id).tag($0.id) }
                    }
                }
                if !epics.isEmpty {
                    Picker("Epic", selection: $epic) {
                        Text("None").tag("")
                        ForEach(epics, id: \.id) { Text($0.name ?? $0.id).tag($0.id) }
                    }
                }
            }
            Section("Description") {
                TextEditor(text: $body_).frame(minHeight: 200)
                    .font(.system(.body, design: .monospaced))
            }
        }
        .formStyle(.grouped)
    }

    @ToolbarContentBuilder private var editToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { seeded = false; seed(); editing = false }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                Task {
                    await model.updateCard(card, title: title, laneID: laneID, priority: priority,
                                           type: type, assignee: assignee, epic: epic, body: body_)
                    dismiss()
                }
            }
            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func seed() {
        guard !seeded else { return }
        seeded = true
        title = card.fields.title
        laneID = laneForStatus?.id ?? lanes.first?.id ?? ""
        priority = card.fields.priority ?? ""
        type = card.fields.type ?? ""
        assignee = card.fields.assignee ?? ""
        epic = card.fields.epic ?? ""
        body_ = card.body.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Create a task in a lane.
struct NewTaskSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let lane: Lane

    @State private var title = ""
    @State private var laneID = ""
    @State private var priority = ""
    @State private var type = ""
    @State private var assignee = ""
    @State private var epic = ""
    @State private var body_ = ""

    private var config: EffectiveConfig? { model.board?.config }
    private var lanes: [Lane] { config?.lanes.filter { !$0.folder.isEmpty } ?? [] }
    private var priorities: [Priority] { config?.priorities ?? [] }
    private var users: [User] { config?.users ?? [] }
    private var types: [String] { config?.types ?? [] }
    private var epics: [Epic] { config?.epics ?? [] }
    private var targetLane: Lane { lanes.first { $0.id == laneID } ?? lane }

    var body: some View {
        NavigationStack {
            Form {
                Section("New Task") {
                    TextField("Title", text: $title)
                    Picker("Lane", selection: $laneID) {
                        ForEach(lanes) { Text($0.name).tag($0.id) }
                    }
                }
                Section {
                    if !priorities.isEmpty {
                        Picker("Priority", selection: $priority) {
                            Text("None").tag("")
                            ForEach(priorities, id: \.id) { Text($0.name ?? $0.id).tag($0.id) }
                        }
                    }
                    if types.isEmpty {
                        TextField("Type", text: $type)
                    } else {
                        Picker("Type", selection: $type) {
                            Text("None").tag("")
                            ForEach(types, id: \.self) { Text($0).tag($0) }
                        }
                    }
                    if users.isEmpty {
                        TextField("Assignee", text: $assignee)
                    } else {
                        Picker("Assignee", selection: $assignee) {
                            Text("Unassigned").tag("")
                            ForEach(users, id: \.id) { Text($0.name ?? $0.id).tag($0.id) }
                        }
                    }
                    if !epics.isEmpty {
                        Picker("Epic", selection: $epic) {
                            Text("None").tag("")
                            ForEach(epics, id: \.id) { Text($0.name ?? $0.id).tag($0.id) }
                        }
                    }
                }
                Section("Description") { TextEditor(text: $body_).frame(minHeight: 140) }
            }
            .formStyle(.grouped)
            .navigationTitle("New Task")
            .onAppear { if laneID.isEmpty { laneID = lane.id } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await model.createTask(
                                title: title, lane: targetLane,
                                priority: priority.isEmpty ? nil : priority,
                                type: type.isEmpty ? nil : type,
                                assignee: assignee.isEmpty ? nil : assignee,
                                epic: epic.isEmpty ? nil : epic,
                                body: body_
                            )
                            dismiss()
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 520)
    }
}

/// A single attachment row with a thumbnail (for images) or a file icon.
private struct AttachmentRow: View {
    @Environment(AppModel.self) private var model
    let entry: BoardFileEntry
    @State private var thumb: NSImage?

    private var isImage: Bool {
        [".png", ".jpg", ".jpeg", ".gif", ".heic", ".webp", ".bmp", ".tiff"]
            .contains { entry.name.lowercased().hasSuffix($0) }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.4))
                if let thumb {
                    Image(nsImage: thumb).resizable().scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: isImage ? "photo" : "doc").foregroundStyle(.secondary)
                }
            }
            .frame(width: 44, height: 44)
            Text(entry.name).font(.callout).lineLimit(1)
            Spacer(minLength: 8)
            Image(systemName: "square.and.arrow.down").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .task(id: entry.path) {
            guard isImage, thumb == nil else { return }
            if let data = await model.readAttachment(path: entry.path), let img = NSImage(data: data) {
                thumb = img
            }
        }
    }
}
