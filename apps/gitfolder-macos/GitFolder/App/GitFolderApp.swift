import SwiftUI

@main
struct GitFolderApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(appModel)
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environment(appModel)
                .onAppear {
                    appModel.loadIfNeeded()
                }
        }
        .windowResizability(.contentSize)
    }

    init() {
        let model = AppModel()
        _appModel = State(initialValue: model)
        Task { @MainActor in
            model.loadIfNeeded()
            DispatchQueue.main.async {
                model.requestLaunchAtLoginIfNeeded()
            }
        }
    }
}
