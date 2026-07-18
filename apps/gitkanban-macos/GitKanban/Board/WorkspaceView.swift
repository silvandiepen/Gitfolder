import GitKit
import SwiftUI

/// The working screen: a sidebar of projects and the selected project's board.
struct WorkspaceView: View {
    @Environment(AppModel.self) private var model

    /// A sidebar row's stable key: repo id + project id (project folders can repeat
    /// across repos, so the repo must be part of the key).
    private func rowKey(_ repoID: String, _ projectID: String) -> String {
        "\(repoID)\u{1}\(projectID)"
    }

    private var selection: Binding<String?> {
        Binding(
            get: {
                guard let repo = model.activeRepo?.fullName, let proj = model.selectedProject?.id else { return nil }
                return rowKey(repo, proj)
            },
            set: { key in
                guard let key else { return }
                let parts = key.components(separatedBy: "\u{1}")
                guard parts.count == 2,
                      let connected = model.connectedRepos.first(where: { $0.id == parts[0] }),
                      let project = connected.workspace?.projects.first(where: { $0.id == parts[1] })
                else { return }
                model.openProject(project, in: connected)
            }
        )
    }

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: selection) {
                    ForEach(model.connectedRepos) { connected in
                        Section {
                            let projects = connected.workspace?.projects ?? []
                            if projects.isEmpty {
                                Text("No projects yet")
                                    .font(.caption).foregroundStyle(.tertiary)
                                    .padding(.vertical, 2)
                            } else {
                                ForEach(projects) { project in
                                    ProjectRow(
                                        project: project,
                                        rootLaneCount: connected.workspace?.rootConfig.lanes.count ?? 0
                                    )
                                    .tag(rowKey(connected.id, project.id))
                                    .contextMenu {
                                        Button("Project Settings…") {
                                            model.openProject(project, in: connected)
                                            model.settingsProject = project
                                        }
                                        Button("Reveal in Finder") {
                                            model.openProject(project, in: connected)
                                            model.revealInFinder(project)
                                        }
                                        Divider()
                                        Button("New Project in \(connected.repo.name)…") {
                                            model.activate(connected, project: nil)
                                            model.isShowingNewProjectSheet = true
                                        }
                                        Button("Refresh") { Task { await model.refreshRepo(connected) } }
                                    }
                                }
                            }
                        } header: {
                            repoHeader(connected)
                        }
                    }
                }

                Divider()
                NewProjectButton { model.isShowingNewProjectSheet = true }
                    .padding(12)
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            BoardView(showNewProject: $model.isShowingNewProjectSheet)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                if let repo = model.activeRepo {
                    Menu {
                        ForEach(model.connectedRepos) { connected in
                            Button {
                                model.activate(connected, project: connected.workspace?.projects.first)
                            } label: {
                                Label(connected.repo.fullName,
                                      systemImage: connected.repo.fullName == repo.fullName ? "checkmark" : "book.closed")
                            }
                        }
                        Divider()
                        Button("Manage Repositories…") { model.isShowingRepoPicker = true }
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
            NewProjectSheet().environment(model)
        }
        .sheet(item: $model.settingsProject) { project in
            NewProjectSheet(editing: project).environment(model)
        }
        .sheet(isPresented: $model.isShowingRepoPicker) {
            RepoPickerView(isSheet: true)
                .environment(model)
                .frame(minWidth: 460, minHeight: 420)
        }
    }

    /// Sidebar section header for one connected repo: name + a menu to add a project,
    /// refresh, or disconnect it.
    private func repoHeader(_ connected: ConnectedRepo) -> some View {
        HStack(spacing: 6) {
            Image(systemName: connected.repo.isPrivate ? "lock.fill" : "book.closed.fill")
                .font(.caption2).foregroundStyle(.tertiary)
            Text(connected.repo.fullName)
                .font(.caption).fontWeight(.semibold)
                .lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 4)
            Menu {
                Button("New Project…") {
                    model.activate(connected, project: nil)
                    model.isShowingNewProjectSheet = true
                }
                Button("Refresh") { Task { await model.refreshRepo(connected) } }
                Divider()
                Button("Disconnect", role: .destructive) { model.disconnectRepo(connected) }
            } label: {
                Image(systemName: "ellipsis").font(.caption)
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
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
