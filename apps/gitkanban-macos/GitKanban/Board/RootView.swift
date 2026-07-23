import GitKit
import GitKanbanKit
import GitPontCore
import SwiftUI

/// Top-level flow: restore → connect → a split view with the boards sidebar + board.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.isRestoring {
            ProgressView("Loading…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.isDemo {
            NavigationStack { BoardScreen() }
        } else if !model.isConnected {
            NavigationStack { ConnectView() }
        } else {
            WorkspaceSplit()
        }
    }
}

/// The connected working screen: a sidebar of added repos + their boards, and the
/// selected board in the detail pane.
private struct WorkspaceSplit: View {
    @Environment(AppModel.self) private var model
    @State private var showAdd = false
    @State private var browseRepo: AddedRepo?

    /// Sidebar selection is a "repoID|folder" key mirroring the open board.
    private var selection: Binding<String?> {
        Binding(
            get: { model.activeRepo.map { "\($0.id)|\(model.activeBoardFolder ?? "")" } },
            set: { key in
                guard let key, let sep = key.range(of: "|") else { return }
                let repoID = String(key[..<sep.lowerBound])
                let folder = String(key[sep.upperBound...])
                if let repo = model.addedRepos.first(where: { $0.id == repoID }) {
                    Task { await model.openBoard(repo, folder: folder) }
                }
            }
        )
    }

    var body: some View {
        NavigationSplitView {
            List(selection: selection) {
                ForEach(model.addedRepos) { repo in
                    Section {
                        if repo.boards.isEmpty {
                            Button { browseRepo = repo } label: {
                                Label("Browse boards…", systemImage: "square.grid.2x2")
                            }
                        } else {
                            ForEach(repo.boards) { board in
                                Label(board.name, systemImage: "square.stack.3d.up.fill")
                                    .tag("\(repo.id)|\(board.folder)")
                            }
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: repo.isPrivate ? "lock.fill" : "book.closed").font(.caption2)
                            Text(repo.fullName).font(.caption)
                            Spacer()
                            Menu {
                                Button("Browse Boards…", systemImage: "square.grid.2x2") { browseRepo = repo }
                                Button("Remove Repository", systemImage: "trash", role: .destructive) { model.removeAddedRepo(repo) }
                            } label: { Image(systemName: "ellipsis") }
                                .menuStyle(.borderlessButton).fixedSize()
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
            .overlay {
                if model.addedRepos.isEmpty {
                    ContentUnavailableView {
                        Label("No Boards", systemImage: "square.stack.3d.up")
                    } description: {
                        Text("Add a repository, then browse it to pick boards.")
                    } actions: {
                        Button("Add Repository") { showAdd = true }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Label("Add Repository", systemImage: "plus") }
                }
                ToolbarItem(placement: .navigation) {
                    Menu {
                        if let login = model.connection?.login { Text("Signed in as \(login)") }
                        Button("Sign Out", role: .destructive) { model.signOut() }
                    } label: { Image(systemName: "person.crop.circle") }
                }
            }
        } detail: {
            if model.activeRepo != nil {
                BoardScreen()
            } else {
                VStack(spacing: 14) {
                    Image("GitKanbanLines")
                        .resizable().scaledToFit().frame(width: 104)
                        .foregroundStyle(.tertiary)
                    Text("Select a board").font(.title2.bold())
                    Text("Choose a board from the sidebar, or add a repository.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showAdd) { NavigationStack { AddRepoView() }.environment(model).frame(minWidth: 460, minHeight: 480) }
        .sheet(item: $browseRepo) { repo in NavigationStack { BoardPickerView(repo: repo) }.environment(model).frame(minWidth: 460, minHeight: 480) }
    }
}

/// Provider-agnostic connect: GitHub (OAuth or token), GitLab.com, or self-hosted GitLab.
private struct ConnectView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    @State private var choice: ProviderChoice = .github
    @State private var serverURL = ""
    @State private var token = ""

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    Image("GitKanbanLines")
                        .resizable().scaledToFit().frame(width: 92, height: 84)
                        .foregroundStyle(.tint)
                    Text("GitKanban").font(.title.bold())
                    Text("Your kanban board is a git repo.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            if let device = model.deviceAuth {
                deviceCodeSection(device)
            } else {
                Section("Provider") {
                    Picker("Provider", selection: $choice) {
                        ForEach(ProviderChoice.allCases) { Text($0.title).tag($0) }
                    }
                    if choice.needsServerURL {
                        TextField("GitLab server URL (e.g. git.acme.com)", text: $serverURL)
                            .autocorrectionDisabled()
                    }
                }

                if choice == .github {
                    Section {
                        Button {
                            Task { await model.startGitHubOAuth() }
                        } label: {
                            HStack {
                                Image(systemName: "person.badge.key.fill")
                                Text("Sign in with GitHub")
                                Spacer()
                                if model.isConnecting { ProgressView().controlSize(.small) }
                            }
                        }
                        .disabled(model.isConnecting)
                    } footer: {
                        Text("Opens github.com to authorise — no token to create.")
                    }
                }

                Section {
                    SecureField("Personal access token", text: $token)
                        .autocorrectionDisabled()
                    Button {
                        Task { await model.connect(choice: choice, serverURL: serverURL, token: token) }
                    } label: {
                        HStack {
                            Spacer()
                            if model.isConnecting && model.deviceAuth == nil { ProgressView().controlSize(.small) }
                            else { Text("Connect with Token").fontWeight(.semibold) }
                            Spacer()
                        }
                    }
                    .disabled(model.isConnecting || token.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Text(choice == .github ? "Or use a token" : "Personal access token")
                } footer: {
                    Text("Create a token with repository read/write scope in your provider's settings.")
                }

                Section {
                    Button {
                        Task { await model.loadDemo() }
                    } label: {
                        Label("Preview a demo board", systemImage: "sparkles")
                    }
                } footer: {
                    Text("Explore the app offline with a sample board — no account needed.")
                }
            }

            if let error = model.errorMessage {
                Section { Text(error).font(.callout).foregroundStyle(.red) }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 520)
        .navigationTitle("Connect")
    }

    private func deviceCodeSection(_ device: GitOAuthDeviceSession) -> some View {
        Section("Sign in with GitHub") {
            VStack(spacing: 12) {
                Text("Enter this code at GitHub to authorise GitKanban:")
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(device.userCode)
                    .font(.system(.largeTitle, design: .monospaced).weight(.bold))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                HStack {
                    Button { Platform.copy(device.userCode) } label: { Label("Copy Code", systemImage: "doc.on.doc") }
                    Spacer()
                    Button { openURL(device.verificationURI) } label: { Label("Open GitHub", systemImage: "safari") }
                        .buttonStyle(.borderedProminent)
                }
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Waiting for authorisation…").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel", role: .cancel) { model.cancelOAuth() }
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 4)
            .onAppear { openURL(device.verificationURI) }
        }
    }
}

/// Home: added repos, each showing the boards you picked. Add a repo, browse it, open a board.
private struct AddRepoView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var picked: AddedRepo?

    private var available: [GitRepository] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return model.repos }
        return model.repos.filter { model.fullName($0).lowercased().contains(q) }
    }

    var body: some View {
        Group {
            if model.isLoadingRepos && model.repos.isEmpty {
                ProgressView("Loading repositories…")
            } else {
                List(available, id: \.reference) { repo in
                    Button {
                        picked = model.addRepo(repo)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: repo.isPrivate ? "lock.fill" : "book.closed").foregroundStyle(.secondary)
                            Text(model.fullName(repo)).foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .searchable(text: $query, prompt: "Filter repositories")
            }
        }
        .navigationTitle("Add Repository")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        }
        .task { if model.repos.isEmpty { await model.loadRepos() } }
        .navigationDestination(item: $picked) { repo in
            BoardPickerView(repo: repo, onDone: { dismiss() })
        }
    }
}

/// Browse a repo's folders and check whichever ones you want as boards.
private struct BoardPickerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let repo: AddedRepo
    var onDone: (() -> Void)? = nil

    @State private var selected: [String: String] = [:]

    var body: some View {
        FolderLevel(repo: repo, path: "", title: repo.name, selected: $selected) {
            let boards = selected.map { SelectedBoard(folder: $0.key, name: $0.value) }
            model.setBoards(boards, for: repo.id)
            if let onDone { onDone() } else { dismiss() }
        }
        .onAppear {
            if selected.isEmpty {
                selected = Dictionary(uniqueKeysWithValues: repo.boards.map { ($0.folder, $0.name) })
            }
        }
    }
}

/// One level of the repo folder tree. Check a folder to include it as a board; open it to go deeper.
private struct FolderLevel: View {
    @Environment(AppModel.self) private var model
    let repo: AddedRepo
    let path: String
    let title: String
    @Binding var selected: [String: String]
    let commit: () -> Void

    @State private var folders: [BoardFileEntry]?

    private func name(for folderPath: String) -> String {
        folderPath.split(separator: "/").last.map(String.init) ?? repo.name
    }
    private func toggle(_ folderPath: String) {
        if selected[folderPath] != nil { selected[folderPath] = nil }
        else { selected[folderPath] = name(for: folderPath) }
    }

    var body: some View {
        List {
            Section {
                Button { toggle(path) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: selected[path] != nil ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selected[path] != nil ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        Text(path.isEmpty ? "Use repository root as a board" : "Use “\(title)” as a board")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Section("Folders") {
                if let folders {
                    if folders.isEmpty { Text("No subfolders").foregroundStyle(.secondary) }
                    ForEach(folders, id: \.path) { entry in
                        HStack(spacing: 12) {
                            Button { toggle(entry.path) } label: {
                                Image(systemName: selected[entry.path] != nil ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected[entry.path] != nil ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                            }
                            .buttonStyle(.plain)
                            NavigationLink {
                                FolderLevel(repo: repo, path: entry.path, title: entry.name, selected: $selected, commit: commit)
                                    .environment(model)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "folder.fill").foregroundStyle(.tint)
                                    Text(entry.name)
                                }
                            }
                        }
                    }
                } else {
                    HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Loading…").foregroundStyle(.secondary) }
                }
            }
        }
        .navigationTitle(path.isEmpty ? "Select Boards" : title)
        .task { folders = await model.listFolders(in: repo, at: path) }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { commit() } }
        }
    }
}
