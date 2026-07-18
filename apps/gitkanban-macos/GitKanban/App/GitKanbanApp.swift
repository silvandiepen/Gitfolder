import SwiftUI

@main
struct GitKanbanApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task { await model.restore() }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Project…") {
                    model.isShowingNewProjectSheet = true
                }
                .keyboardShortcut("n", modifiers: [.command])
                .disabled(model.activeRepo == nil)
            }

            CommandGroup(after: .newItem) {
                Button("Refresh") {
                    Task { await model.refresh() }
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(model.activeRepo == nil)

                Button("Sign Out") { model.signOut() }
                    .disabled(!model.isConnected)
            }
        }
    }
}
