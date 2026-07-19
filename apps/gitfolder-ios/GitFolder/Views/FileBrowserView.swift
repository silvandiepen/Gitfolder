import SwiftUI

/// The file browser for the open repository: a navigation stack rooted at the repo
/// root, pushing a `DirectoryView` for folders, an image viewer for images, and a
/// `FileEditorView` for other files.
struct FileBrowserRoot: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            DirectoryView(path: "", title: model.activeRepo?.fullName ?? "Files", isRoot: true)
                .navigationDestination(for: RepoEntry.self) { entry in
                    if entry.isDirectory {
                        DirectoryView(path: entry.path, title: entry.name, isRoot: false)
                    } else if FileKind.isRasterImage(entry.name) {
                        ImageViewerView(path: entry.path, name: entry.name)
                    } else {
                        FileEditorView(path: entry.path, name: entry.name)
                    }
                }
        }
    }
}

/// File-type helpers shared across the browser.
enum FileKind {
    static func isImage(_ name: String) -> Bool {
        let l = name.lowercased()
        return [".png", ".jpg", ".jpeg", ".gif", ".heic", ".webp", ".bmp", ".tiff", ".svg"]
            .contains { l.hasSuffix($0) }
    }
    static func isSVG(_ name: String) -> Bool { name.lowercased().hasSuffix(".svg") }
    /// Raster images we can thumbnail with UIImage (everything but SVG).
    static func isRasterImage(_ name: String) -> Bool { isImage(name) && !isSVG(name) }

    static func icon(_ name: String, isDirectory: Bool) -> String {
        if isDirectory { return "folder.fill" }
        let l = name.lowercased()
        if isImage(name) { return "photo" }
        if l.hasSuffix(".md") || l.hasSuffix(".markdown") { return "doc.richtext" }
        if l.hasSuffix(".json") || l.hasSuffix(".yml") || l.hasSuffix(".yaml") || l.hasSuffix(".toml") { return "curlybraces" }
        return "doc.text"
    }
}

/// How a directory's contents are laid out. Persisted so the choice sticks.
enum BrowseLayout: String, CaseIterable, Identifiable {
    case list, tiles, columns
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .tiles: return "square.grid.2x2"
        case .columns: return "rectangle.grid.2x2"
        }
    }
}

/// One directory's listing, shown as a List, Tiles, or Columns. Folders navigate,
/// files open; supports adding a new file and deleting a file.
struct DirectoryView: View {
    @Environment(AppModel.self) private var model
    let path: String
    let title: String
    let isRoot: Bool

    @AppStorage("gitfolder.browseLayout") private var layoutRaw = BrowseLayout.list.rawValue
    private var layout: BrowseLayout { BrowseLayout(rawValue: layoutRaw) ?? .list }

    @State private var entries: [RepoEntry] = []
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showNewFile = false
    @State private var newFileName = ""
    @State private var shareItem: ShareItem?

    var body: some View {
        content
            .overlay { if isLoading { ProgressView() } }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(isRoot ? .large : .inline)
            .refreshable { await reload() }
            .task { await reload() }
            .toolbar { toolbarContent }
            .alert("New File", isPresented: $showNewFile) {
                TextField("name.md", text: $newFileName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Cancel", role: .cancel) { newFileName = "" }
                Button("Create") { Task { await createFile() } }
            } message: {
                Text("Creates and commits a new file in this folder.")
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item.url])
            }
    }

    // MARK: Layouts

    @ViewBuilder private var content: some View {
        switch layout {
        case .list: listLayout
        case .tiles: gridLayout(columns: [GridItem(.adaptive(minimum: 104), spacing: 16)], spacing: 18) { TileCell(entry: $0) }
        case .columns: gridLayout(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) { ColumnCell(entry: $0) }
        }
    }

    private var listLayout: some View {
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
                        Image(systemName: FileKind.icon(entry.name, isDirectory: entry.isDirectory))
                            .foregroundStyle(entry.isDirectory ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    }
                }
                .swipeActions(edge: .trailing) { deleteButton(entry) }
                .contextMenu { fileActions(entry) }
            }
            if !isLoading && entries.isEmpty && loadError == nil {
                Text("Empty folder").foregroundStyle(.secondary)
            }
        }
    }

    private func gridLayout<Cell: View>(
        columns: [GridItem], spacing: CGFloat, @ViewBuilder cell: @escaping (RepoEntry) -> Cell
    ) -> some View {
        ScrollView {
            if let loadError {
                Label(loadError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red).font(.callout).padding()
            }
            if !isLoading && entries.isEmpty && loadError == nil {
                Text("Empty folder").foregroundStyle(.secondary).padding(.top, 40)
            }
            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(entries) { entry in
                    NavigationLink(value: entry) { cell(entry) }
                        .buttonStyle(.plain)
                        .contextMenu { fileActions(entry) }
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder private func deleteButton(_ entry: RepoEntry) -> some View {
        if !entry.isDirectory {
            Button(role: .destructive) {
                Task { if await model.delete(path: entry.path) { await reload() } }
            } label: { Label("Delete", systemImage: "trash") }
        }
    }

    /// Context-menu actions for a file: share/export, then delete.
    @ViewBuilder private func fileActions(_ entry: RepoEntry) -> some View {
        if !entry.isDirectory {
            Button {
                Task { await shareFile(entry) }
            } label: { Label("Share / Export…", systemImage: "square.and.arrow.up") }
            deleteButton(entry)
        }
    }

    private func shareFile(_ entry: RepoEntry) async {
        guard let data = try? await model.readData(entry.path) else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(entry.name)
        guard (try? data.write(to: url)) != nil else { return }
        shareItem = ShareItem(url: url)
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker("Layout", selection: $layoutRaw) {
                ForEach(BrowseLayout.allCases) { l in
                    Image(systemName: l.icon).tag(l.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 150)
        }
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

    // MARK: Data

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
}
