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

/// The home screen: all boards, grouped by the repo they live in. Tap a board to open
/// it; add more repos (optionally rooted at a subfolder). The set is saved locally.
private struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showAdd = false

    var body: some View {
        Group {
            if model.addedRepos.isEmpty {
                ContentUnavailableView {
                    Label("No Boards", systemImage: "square.stack.3d.up")
                } description: {
                    Text("Add a repository to manage its boards.")
                } actions: {
                    Button("Add Repository") { showAdd = true }.buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(model.addedRepos) { ref in
                        Section {
                            if let boards = model.homeBoards[ref.id] {
                                if boards.isEmpty {
                                    Text("No boards found here").font(.callout).foregroundStyle(.secondary)
                                } else {
                                    ForEach(boards) { project in
                                        Button {
                                            Task { await model.openBoard(ref, project: project) }
                                        } label: {
                                            HStack(spacing: 12) {
                                                Image(systemName: "square.stack.3d.up.fill")
                                                    .font(.title3).foregroundStyle(.tint).frame(width: 26)
                                                Text(project.name).font(.body).foregroundStyle(.primary)
                                                Spacer()
                                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                                            }
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            } else {
                                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Loading boards…").foregroundStyle(.secondary) }
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Image(systemName: ref.isPrivate ? "lock.fill" : "book.closed").font(.caption2)
                                Text(ref.path.isEmpty ? ref.fullName : "\(ref.fullName) / \(ref.path)").textCase(nil)
                                Spacer()
                                Button(role: .destructive) { model.removeAddedRepo(ref) } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.plain).foregroundStyle(.red)
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
                    Button("Refresh Boards") { Task { model.homeBoards = [:]; await model.loadHomeBoards() } }
                    Button("Sign Out", role: .destructive) { model.signOut() }
                } label: { Image(systemName: "person.crop.circle") }
            }
        }
        .task { await model.loadHomeBoards() }
        .sheet(isPresented: $showAdd) {
            NavigationStack { AddBoardView() }.environment(model)
        }
    }
}

/// Pick a repository from the account to add. Optionally root it at a subfolder (e.g.
/// `project-assets/Tasks`) where the boards live.
private struct AddBoardView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var path = ""

    private var available: [GitRepository] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return model.repos }
        return model.repos.filter { model.fullName($0).lowercased().contains(q) }
    }

    var body: some View {
        Form {
            Section {
                TextField("Subfolder (optional, e.g. project-assets/Tasks)", text: $path)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
            } footer: {
                Text("Leave empty to use the repo root. Applies to the repository you pick next.")
            }
            Section("Repository") {
                if model.isLoadingRepos && model.repos.isEmpty {
                    HStack { ProgressView(); Text("Loading…").foregroundStyle(.secondary) }
                }
                ForEach(available, id: \.reference) { repo in
                    Button {
                        Task { await model.addRepo(repo, path: path); dismiss() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: repo.isPrivate ? "lock.fill" : "book.closed").foregroundStyle(.secondary)
                            Text(model.fullName(repo)).foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "plus.circle").foregroundStyle(.tint)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .searchable(text: $query, prompt: "Filter repositories")
        .refreshable { await model.loadRepos() }
        .navigationTitle("Add Repository")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        .task { if model.repos.isEmpty { await model.loadRepos() } }
    }
}
