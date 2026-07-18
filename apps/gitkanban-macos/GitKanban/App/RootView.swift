import SwiftUI

/// Routes between the three top-level states: connect → pick a repo → work the board.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.isRestoring {
                VStack(spacing: 16) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 40)).foregroundStyle(.tint)
                    ProgressView().controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !model.isConnected {
                ConnectView()
            } else if model.connectedRepos.isEmpty {
                RepoPickerView()
            } else {
                WorkspaceView()
            }
        }
        .frame(minWidth: 820, minHeight: 560)
    }
}
