import SwiftUI

/// Pick a destination folder to move something into. Browses the repo's folders;
/// "Move Here" chooses the current folder. The folder being moved (and its
/// descendants) are hidden so you can't move it into itself.
struct FolderPickerView: View {
    let movingPath: String
    let onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            FolderLevel(path: "", title: "Repository", movingPath: movingPath) { dest in
                onPick(dest)
                dismiss()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

private struct FolderLevel: View {
    @Environment(AppModel.self) private var model
    let path: String
    let title: String
    let movingPath: String
    let onPick: (String) -> Void

    @State private var folders: [RepoEntry] = []
    @State private var loading = true

    var body: some View {
        List {
            Section {
                Button {
                    onPick(path)
                } label: {
                    Label(path.isEmpty ? "Move to Repository Root" : "Move Here", systemImage: "arrow.down.to.line")
                }
            }
            Section("Folders") {
                ForEach(folders) { folder in
                    NavigationLink {
                        FolderLevel(path: folder.path, title: folder.name, movingPath: movingPath, onPick: onPick)
                            .environment(model)
                    } label: {
                        Label(folder.name, systemImage: "folder.fill")
                    }
                }
                if folders.isEmpty && !loading {
                    Text("No subfolders").foregroundStyle(.secondary)
                }
            }
        }
        .overlay { if loading { ProgressView() } }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        loading = true
        let entries = (try? await model.list(path)) ?? []
        folders = entries.filter {
            $0.isDirectory && $0.path != movingPath && !$0.path.hasPrefix(movingPath + "/")
        }
        loading = false
    }
}
