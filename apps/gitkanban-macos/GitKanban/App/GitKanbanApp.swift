import SwiftUI

@main
struct GitKanbanApp: App {
    @State private var model = BoardViewModel()

    var body: some Scene {
        WindowGroup {
            BoardView()
                .environment(model)
                .onAppear { model.loadSampleIfEmpty() }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Board Folder…") { model.openFolder() }
                    .keyboardShortcut("o", modifiers: [.command])
            }
        }
    }
}
