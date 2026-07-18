import GitKit
import SwiftUI

/// The working screen: a sidebar of projects and the selected project's board.
struct WorkspaceView: View {
    @Environment(AppModel.self) private var model

    private var projects: [BoardProject] { model.workspace?.projects ?? [] }
    private var rootLaneCount: Int { model.workspace?.rootConfig.lanes.count ?? 0 }

    private var selection: Binding<String?> {
        Binding(
            get: { model.selectedProject?.id },
            set: { newID in
                if let project = projects.first(where: { $0.id == newID }) {
                    model.selectProject(project)
                }
            }
        )
    }

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            Group {
                if projects.isEmpty {
                    VStack {
                        NewProjectButton { model.isShowingNewProjectSheet = true }
                            .padding(16)
                        Spacer()
                    }
                } else {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Projects")
                                .font(.caption).fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(projects.count)")
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)

                        List(projects, selection: selection) { project in
                            ProjectRow(project: project, rootLaneCount: rootLaneCount)
                                .tag(project.id)
                                .contextMenu {
                                    Button("Project Settings…") { model.settingsProject = project }
                                    Button("Reveal in Finder") { model.revealInFinder(project) }
                                    Divider()
                                    Button("Refresh") { Task { await model.refresh() } }
                                }
                        }

                        Divider()
                        NewProjectButton { model.isShowingNewProjectSheet = true }
                            .padding(12)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } detail: {
            BoardView(showNewProject: $model.isShowingNewProjectSheet)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                if let repo = model.activeRepo {
                    Menu {
                        Button("Switch Repository…") { model.closeRepo() }
                        Button("Sign Out") { model.signOut() }
                    } label: {
                        Text(repo.fullName)
                    }
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                if model.board != nil {
                    Button {
                        model.isShowingSearch = true
                    } label: {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .labelStyle(.iconOnly)
                    .help("Search tasks (⌘F)")

                    Picker("View", selection: $model.boardViewMode) {
                        Label("Lanes", systemImage: "rectangle.split.3x1")
                            .tag(BoardViewMode.lanes)
                        Label("List", systemImage: "list.bullet")
                            .tag(BoardViewMode.list)
                    }
                    .pickerStyle(.segmented)
                    .labelStyle(.iconOnly)
                    .help("Switch between lanes and list")
                }

                if model.errorMessage != nil {
                    Button {
                        model.errorMessage = nil
                    } label: {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    }
                    .labelStyle(.iconOnly)
                    .tint(.red)
                    .help(model.errorMessage ?? "")
                }

                Button {
                    model.isShowingNewProjectSheet = true
                } label: {
                    Label("New Project", systemImage: "plus")
                }
                .labelStyle(.iconOnly)
                .help("New project")

                if isSyncing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .labelStyle(.iconOnly)
                    .help("Refresh")
                }
            }
        }
        .sheet(isPresented: $model.isShowingNewProjectSheet) {
            NewProjectSheet(isPresented: $model.isShowingNewProjectSheet)
                .environment(model)
        }
        .sheet(item: $model.settingsProject) { project in
            ProjectSettingsSheet(project: project).environment(model)
        }
    }

    private var isSyncing: Bool {
        model.isCreatingProject
            || ["Pulling…", "Cloning…", "Committing…", "Pushing…", "Creating project…"].contains(model.syncStatus)
    }
}

/// A richer sidebar row: a colour-coded folder, the project name, and a subtitle
/// describing its lanes (and backlog, when it has one).
private struct ProjectRow: View {
    let project: BoardProject
    let rootLaneCount: Int

    private var lanes: [Lane]? { project.config.lanes }
    private var laneCount: Int { lanes?.count ?? rootLaneCount }
    private var hasBacklog: Bool { lanes?.contains { $0.isBacklog } ?? false }
    private var userCount: Int { project.config.users?.count ?? 0 }

    private var color: Color {
        LaneColor.at(abs(project.folder.hashValue) % LaneColor.palette.count)
    }

    private var subtitle: String {
        var parts = ["\(laneCount) lane\(laneCount == 1 ? "" : "s")"]
        if hasBacklog { parts.append("backlog") }
        if userCount > 0 { parts.append("\(userCount) member\(userCount == 1 ? "" : "s")") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.fill")
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(project.name)
                    .font(.callout).fontWeight(.medium)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}
