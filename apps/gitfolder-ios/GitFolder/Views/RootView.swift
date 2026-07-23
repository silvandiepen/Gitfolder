import SwiftUI

/// Top-level flow: restore → connect → home (added repos) → browse & edit files.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.isRestoring {
            ProgressView("Loading…")
        } else if model.activeRepo != nil {
            FileBrowserRoot()
        } else if model.isConnected || model.isDemo {
            NavigationStack { HomeView() }
        } else {
            NavigationStack { ConnectView() }
        }
    }
}
