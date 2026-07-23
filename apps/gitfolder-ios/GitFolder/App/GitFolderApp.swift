import SwiftUI

@main
struct GitFolderApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task {
                    // Test hook: launch with GITFOLDER_DEMO=1 to open the offline demo.
                    if ProcessInfo.processInfo.environment["GITFOLDER_DEMO"] == "1" {
                        model.loadDemo()
                        // Screenshot hook: open one of the demo repos straight away.
                        if let open = ProcessInfo.processInfo.environment["GITFOLDER_DEMO_OPEN"],
                           let ref = model.addedRepos.first(where: { $0.fullName == open }) {
                            model.openRepo(ref)
                        }
                    } else {
                        await model.restore()
                    }
                }
        }
    }
}
