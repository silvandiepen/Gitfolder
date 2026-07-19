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
                    RepoPickerView()
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

/// Pick a repository to open as a board.
private struct RepoPickerView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""

    private var filtered: [GitRepository] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return model.repos }
        return model.repos.filter { model.fullName($0).lowercased().contains(q) }
    }

    var body: some View {
        List {
            if model.isLoadingRepos && model.repos.isEmpty {
                HStack { ProgressView(); Text("Loading repositories…").foregroundStyle(.secondary) }
            }
            ForEach(filtered, id: \.reference) { repo in
                Button {
                    Task { await model.openRepo(repo) }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: repo.isPrivate ? "lock.fill" : "book.closed")
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(repo.reference.name).font(.body)
                            Text(repo.reference.namespace).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .overlay {
            if model.isLoadingBoard {
                ProgressView("Opening board…").padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .searchable(text: $query, prompt: "Search repositories")
        .navigationTitle("Repositories")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Reload") { Task { await model.loadRepos() } }
                    Button("Sign Out", role: .destructive) { model.signOut() }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
    }
}
