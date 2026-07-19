import SwiftUI

/// The file browser for the open repository: a navigation stack rooted at the repo
/// root, pushing a `DirectoryView` for folders and a `FileEditorView` for files.
struct FileBrowserRoot: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            DirectoryView(path: "", title: model.activeRepo.map(model.fullName) ?? "Files", isRoot: true)
                .navigationDestination(for: RepoEntry.self) { entry in
                    if entry.isDirectory {
                        DirectoryView(path: entry.path, title: entry.name, isRoot: false)
                    } else {
                        FileEditorView(path: entry.path, name: entry.name)
                    }
                }
        }
    }
}

/// One directory's listing. Loads entries over the provider API; folders navigate,
/// files open in the editor. Supports adding a new file and deleting a file.
struct DirectoryView: View {
    @Environment(AppModel.self) private var model
    let path: String
    let title: String
    let isRoot: Bool

    @State private var entries: [RepoEntry] = []
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showNewFile = false
    @State private var newFileName = ""

    var body: some View {
        List {
            if let loadError {
                Section {
                    Label(loadError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red).font(.callout)
                }
            }
            ForEach(entries) { entry in
                NavigationLink(value: entry) {
                    Label {
                        Text(entry.name)
                    } icon: {
                        Image(systemName: entry.isDirectory ? "folder.fill" : icon(for: entry.name))
                            .foregroundStyle(entry.isDirectory ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    }
                }
                .swipeActions(edge: .trailing) {
                    if !entry.isDirectory {
                        Button(role: .destructive) {
                            Task { if await model.delete(path: entry.path) { await reload() } }
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
            if !isLoading && entries.isEmpty && loadError == nil {
                Text("Empty folder").foregroundStyle(.secondary)
            }
        }
        .overlay { if isLoading { ProgressView() } }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(isRoot ? .large : .inline)
        .refreshable { await reload() }
        .task { await reload() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showNewFile = true } label: { Label("New File", systemImage: "doc.badge.plus") }
                    Button { Task { await reload() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                    if isRoot {
                        Divider()
                        Button { model.closeRepo() } label: { Label("Close Repository", systemImage: "xmark") }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("New File", isPresented: $showNewFile) {
            TextField("name.md", text: $newFileName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) { newFileName = "" }
            Button("Create") { Task { await createFile() } }
        } message: {
            Text("Creates and commits a new file in this folder.")
        }
    }

    private func reload() async {
        isLoading = true
        loadError = nil
        do {
            entries = try await model.list(path)
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    private func createFile() async {
        let name = newFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        newFileName = ""
        guard !name.isEmpty else { return }
        let fullPath = path.isEmpty ? name : "\(path)/\(name)"
        if await model.createFile(path: fullPath, text: "") { await reload() }
    }

    private func icon(for name: String) -> String {
        let lower = name.lowercased()
        if lower.hasSuffix(".md") || lower.hasSuffix(".markdown") { return "doc.richtext" }
        if lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") || lower.hasSuffix(".gif") || lower.hasSuffix(".svg") { return "photo" }
        if lower.hasSuffix(".json") || lower.hasSuffix(".yml") || lower.hasSuffix(".yaml") || lower.hasSuffix(".toml") { return "curlybraces" }
        return "doc.text"
    }
}
