import GitKit
import GitPontCore
import SwiftUI
import UIKit

/// Top-level flow: restore → connect → pick a repo → board.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            Group {
                if model.isRestoring {
                    ProgressView("Loading…")
                } else if model.activeRepo != nil || model.isDemo {
                    BoardScreen()
                } else if !model.isConnected {
                    ConnectView()
                } else {
                    HomeView()
                }
            }
        }
    }
}

/// Provider-agnostic connect: pick GitHub, GitLab.com, or a self-hosted GitLab, and
/// paste a personal access token. A token works against any instance without
/// per-server OAuth registration.
private struct ConnectView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    @State private var choice: ProviderChoice = .github
    @State private var serverURL = ""
    @State private var token = ""

    var body: some View {
        Form {
            Section {
                VStack(spacing: 6) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 44)).foregroundStyle(.tint)
                    Text("GitKanban").font(.title.bold())
                    Text("Your kanban board is a git repo.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            if let device = model.deviceAuth {
                deviceCodeSection(device)
            } else {
                Section("Provider") {
                    Picker("Provider", selection: $choice) {
                        ForEach(ProviderChoice.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                    if choice.needsServerURL {
                        TextField("GitLab server URL (e.g. git.acme.com)", text: $serverURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
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
                                if model.isConnecting { ProgressView() }
                            }
                        }
                        .disabled(model.isConnecting)
                    } footer: {
                        Text("Opens github.com to authorise — no token to create.")
                    }
                }

                Section {
                    SecureField("Personal access token", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        Task { await model.connect(choice: choice, serverURL: serverURL, token: token) }
                    } label: {
                        HStack {
                            Spacer()
                            if model.isConnecting && model.deviceAuth == nil { ProgressView() }
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
        .navigationTitle("Connect")
    }

    /// Device-flow UI: show the user code, open the verification page, and wait.
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
                    Button {
                        UIPasteboard.general.string = device.userCode
                    } label: { Label("Copy Code", systemImage: "doc.on.doc") }
                        .buttonStyle(.borderless)
                    Spacer()
                    Button {
                        openURL(device.verificationURI)
                    } label: { Label("Open GitHub", systemImage: "safari") }
                        .buttonStyle(.borderedProminent)
                }

                HStack(spacing: 8) {
                    ProgressView()
                    Text("Waiting for authorisation…").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel", role: .cancel) { model.cancelOAuth() }
                        .buttonStyle(.borderless)
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 4)
            .onAppear { openURL(device.verificationURI) }
        }
    }
}

/// The home screen: added repos, each showing the boards you picked from it. Tap a
/// board to open it. Add a repo, then browse it to select boards. Saved locally.
private struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showAdd = false
    @State private var browseRepo: AddedRepo?

    /// "N tasks · <folder>" for a board row (task count loads lazily).
    private func boardSubtitle(_ repo: AddedRepo, _ board: SelectedBoard) -> String {
        var parts: [String] = []
        if let n = model.boardCount(repo, board.folder) { parts.append("\(n) task\(n == 1 ? "" : "s")") }
        if !board.folder.isEmpty { parts.append(board.folder) }
        return parts.isEmpty ? "Loading…" : parts.joined(separator: " · ")
    }

    var body: some View {
        Group {
            if model.addedRepos.isEmpty {
                ContentUnavailableView {
                    Label("No Boards", systemImage: "square.stack.3d.up")
                } description: {
                    Text("Add a repository, then browse it to pick which boards to show.")
                } actions: {
                    Button("Add Repository") { showAdd = true }.buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(model.addedRepos) { repo in
                        Section {
                            if repo.boards.isEmpty {
                                Button { browseRepo = repo } label: {
                                    Label("Browse boards…", systemImage: "square.grid.2x2")
                                }
                            } else {
                                ForEach(repo.boards) { board in
                                    Button {
                                        Task { await model.openBoard(repo, folder: board.folder) }
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: "square.stack.3d.up.fill")
                                                .font(.title3).foregroundStyle(.tint).frame(width: 26)
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(board.name).font(.body).foregroundStyle(.primary)
                                                Text(boardSubtitle(repo, board)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                            }
                                            Spacer(minLength: 8)
                                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .task { await model.loadBoardCount(repo, board.folder) }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) { model.removeBoard(board, from: repo) } label: {
                                            Label("Remove", systemImage: "minus.circle")
                                        }
                                    }
                                }
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Image(systemName: repo.isPrivate ? "lock.fill" : "book.closed").font(.caption2)
                                Text(repo.fullName).textCase(nil)
                                Spacer()
                                Menu {
                                    Button("Browse Boards…", systemImage: "square.grid.2x2") { browseRepo = repo }
                                    Button("Remove Repository", systemImage: "trash", role: .destructive) { model.removeAddedRepo(repo) }
                                } label: { Image(systemName: "ellipsis.circle") }
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if model.isLoadingBoard {
                ProgressView("Opening board…").padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .navigationTitle("Boards")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    if let login = model.connection?.login { Text("Signed in as \(login)") }
                    Button("Sign Out", role: .destructive) { model.signOut() }
                } label: { Image(systemName: "person.crop.circle") }
            }
        }
        .sheet(isPresented: $showAdd) { NavigationStack { AddRepoView() }.environment(model) }
        .sheet(item: $browseRepo) { repo in NavigationStack { BoardPickerView(repo: repo) }.environment(model) }
    }
}

/// Pick a repository from the account to add. After adding, browse it to select boards.
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
                .refreshable { await model.loadRepos() }
            }
        }
        .navigationTitle("Add Repository")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        .task { if model.repos.isEmpty { await model.loadRepos() } }
        .navigationDestination(item: $picked) { repo in
            BoardPickerView(repo: repo, onDone: { dismiss() })
        }
    }
}

/// Browse a repo's folders and check whichever ones you want as boards — no scanning
/// or heuristics; you pick the folders directly, at any depth.
private struct BoardPickerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let repo: AddedRepo
    var onDone: (() -> Void)? = nil

    /// folder path → display name of the boards you've checked.
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

/// One level of the repo folder tree. Check a folder to include it as a board; tap it to
/// go deeper. Done saves from any level.
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
                    if folders.isEmpty {
                        Text("No subfolders").foregroundStyle(.secondary)
                    }
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
        .navigationBarTitleDisplayMode(.inline)
        .task { folders = await model.listFolders(in: repo, at: path) }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { commit() }
            }
        }
    }
}
