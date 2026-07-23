import SwiftUI
import GitKanbanKit

@main
struct GitKanbanApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .frame(minWidth: 900, minHeight: 600)
                .task {
                    // Test hook: launch with GITKANBAN_DEMO=1 to open the offline demo.
                    if ProcessInfo.processInfo.environment["GITKANBAN_DEMO"] == "1" {
                        await model.loadDemo()
                    } else {
                        await model.restore()
                    }
                }
        }
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Refresh Board") {
                    Task {
                        if let repo = model.activeRepo, let folder = model.activeBoardFolder {
                            await model.openBoard(repo, folder: folder)
                        }
                    }
                }
                .keyboardShortcut("r")
                .disabled(model.activeRepo == nil)

                Button("Find…") { model.isShowingSearch = true }
                    .keyboardShortcut("f")
                    .disabled(model.board == nil)
            }
        }
    }
}

/// Small AppKit helpers so the ported views can copy/open/save on macOS.
enum Platform {
    static func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
    static func open(_ url: URL) { NSWorkspace.shared.open(url) }

    /// Present a save panel to write `data` to a user-chosen location.
    @MainActor static func save(data: Data, suggestedName: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }
}
