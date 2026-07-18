import SwiftUI

@main
struct GitKanbanApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task {
                    // Test hook: launch with GITKANBAN_DEMO=1 to open the offline demo.
                    if ProcessInfo.processInfo.environment["GITKANBAN_DEMO"] == "1" {
                        await model.loadDemo()
                    } else {
                        await model.restore()
                    }
                }
        }
    }
}
