import SwiftUI

/// Routes between the three top-level states: connect → pick a repo → work the board.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if !model.isConnected {
                ConnectView()
            } else if model.activeRepo == nil {
                RepoPickerView()
            } else {
                WorkspaceView()
            }
        }
        .frame(minWidth: 820, minHeight: 560)
    }
}
