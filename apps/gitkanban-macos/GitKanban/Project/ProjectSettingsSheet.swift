import GitKit
import SwiftUI

/// Project settings: shows the project's effective config (lanes, priorities,
/// assignees). Editing (colours, vocabulary) lands with the config-in-YAML work.
struct ProjectSettingsSheet: View {
    @Environment(AppModel.self) private var model
    let project: BoardProject

    private var config: EffectiveConfig {
        if let board = model.board, model.selectedProject?.id == project.id {
            return board.config
        }
        return resolveEffectiveConfig(model.workspace?.rootConfig ?? BoardConfig(), project.config)
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
                    LabeledContent("Name", value: project.name)
                    LabeledContent("Folder", value: project.folder)
                }
                Section("Lanes") {
                    ForEach(Array(config.lanes.enumerated()), id: \.element.id) { index, lane in
                        HStack(spacing: 8) {
                            Circle().fill(LaneColor.at(index)).frame(width: 9, height: 9)
                            Text(lane.name)
                            Spacer()
                            Text(lane.status).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if !config.priorities.isEmpty {
                    Section("Priorities") {
                        ForEach(config.priorities, id: \.id) { priority in
                            HStack(spacing: 8) {
                                Circle().fill(PriorityColor.color(for: priority.id, in: config.priorities) ?? .gray)
                                    .frame(width: 9, height: 9)
                                Text(priority.id)
                                Spacer()
                                if let name = priority.name, !name.isEmpty {
                                    Text(name).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                if !config.users.isEmpty {
                    Section("Assignees") {
                        ForEach(config.users, id: \.id) { LabeledContent($0.id, value: $0.name ?? "") }
                    }
                }
                Section {
                    Text("Editing config — colours, lanes, and vocabulary — is coming. It's stored in the project's README/config in the repo.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Button("Reveal in Finder") { model.revealInFinder(project) }
                Spacer()
                Button("Done") { model.settingsProject = nil }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 460, height: 560)
    }
}
