import GitKit
import SwiftUI

/// Create a task (card) in the current project. Fields (lane, priority, type,
/// assignee) come from the board's effective config. On Create it writes the
/// card and commits + pushes it.
struct NewTaskSheet: View {
    @Environment(AppModel.self) private var model
    let lane: Lane

    @State private var title = ""
    @State private var selectedLaneID: String
    @State private var priority = ""
    @State private var type = ""
    @State private var assignee = ""
    @State private var notes = ""

    init(lane: Lane) {
        self.lane = lane
        _selectedLaneID = State(initialValue: lane.id)
    }

    private var config: EffectiveConfig? { model.board?.config }
    private var lanes: [Lane] { config?.lanes ?? [lane] }
    private var priorities: [Priority] { config?.priorities ?? [] }
    private var users: [User] { config?.users ?? [] }
    private var types: [String] { config?.types ?? [] }
    private var resolvedLane: Lane { lanes.first { $0.id == selectedLaneID } ?? lane }
    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "checklist")
                    .font(.title2).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text("New Task").font(.headline)
                    Text("in \(resolvedLane.name)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(16)
            Divider()

            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $notes, axis: .vertical).lineLimit(3...8)
                }
                Section {
                    Picker("Lane", selection: $selectedLaneID) {
                        ForEach(lanes) { Text($0.name).tag($0.id) }
                    }
                    if !priorities.isEmpty {
                        Picker("Priority", selection: $priority) {
                            Text("None").tag("")
                            ForEach(priorities, id: \.id) { Text($0.name ?? $0.id).tag($0.id) }
                        }
                    }
                    if !types.isEmpty {
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
                }
            }
            .formStyle(.grouped)

            Divider()
            footer
        }
        .frame(width: 460, height: 500)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            if let error = model.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    Text(error).font(.caption).foregroundStyle(.red).lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.top, 10)
            }
            HStack(spacing: 10) {
                Spacer()
                Button("Cancel") { model.newTaskLane = nil }
                    .keyboardShortcut(.cancelAction)
                Button {
                    Task { await create() }
                } label: {
                    if model.isCreatingTask {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Create Task")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(trimmedTitle.isEmpty || model.isCreatingTask)
            }
            .padding(16)
        }
    }

    private func create() async {
        await model.createTask(
            title: trimmedTitle,
            lane: resolvedLane,
            priority: priority.isEmpty ? nil : priority,
            type: type.isEmpty ? nil : type,
            assignee: assignee.isEmpty ? nil : assignee,
            body: notes
        )
        if model.errorMessage == nil { model.newTaskLane = nil }
    }
}
