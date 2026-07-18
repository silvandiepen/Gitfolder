import GitKit
import SwiftUI

/// The working screen: a sidebar of projects and the selected project's board.
struct WorkspaceView: View {
    @Environment(AppModel.self) private var model

    private var projects: [BoardProject] { model.workspace?.projects ?? [] }

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
                        NewProjectButton { model.isShowingNewProjectSheet = true }
                            .padding([.horizontal, .top], 12)
                        List(projects, selection: selection) { project in
                            Label(project.name, systemImage: "folder")
                                .tag(project.id)
                                .contextMenu {
                                    Button("Project Settings…") { model.settingsProject = project }
                                    Button("Reveal in Finder") { model.revealInFinder(project) }
                                    Divider()
                                    Button("Refresh") { Task { await model.refresh() } }
                                }
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
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
