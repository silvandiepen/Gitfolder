import GitKit
import SwiftUI

/// The working screen: a sidebar of projects and the selected project's board.
struct WorkspaceView: View {
    @Environment(AppModel.self) private var model

    private var selection: Binding<String?> {
        Binding(
            get: { model.selectedProject?.id },
            set: { newID in
                if let project = model.workspace?.projects.first(where: { $0.id == newID }) {
                    model.selectProject(project)
                }
            }
        )
    }

    var body: some View {
        NavigationSplitView {
            List(model.workspace?.projects ?? [], selection: selection) { project in
                Label(project.name, systemImage: "folder")
                    .tag(project.id)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            BoardView()
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                if let repo = model.activeRepo {
                    Text(repo.fullName).font(.headline)
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Text(model.syncStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    Task { await model.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Pull and reload")
                Button("Repos") { model.closeRepo() }
                    .help("Choose another repository")
                Button("Sign out") { model.signOut() }
            }
        }
    }
}
