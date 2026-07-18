import GitKit
import SwiftUI

/// Pick a repository to open. Tapping a repo clones it into the app's own checkout.
struct RepoPickerView: View {
    @Environment(AppModel.self) private var model
    /// When shown as a sheet ("Add Repository"), offers a Close button instead of
    /// taking over the whole window.
    var isSheet = false
    @State private var search = ""

    /// Repos not already connected (a repo can only be connected once).
    private var availableRepos: [GitHubRepo] {
        let connected = Set(model.connectedRepos.map(\.id))
        return model.repos.filter { !connected.contains($0.fullName) }
    }

    private var filtered: [GitHubRepo] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return availableRepos }
        return availableRepos.filter { $0.fullName.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(isSheet ? "Manage repositories" : "Choose a repository").font(.headline)
                if let login = model.login {
                    Text("Signed in as \(login)").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isSheet {
                Button("Close") { model.isShowingRepoPicker = false }
            } else {
                Button("Sign out") { model.signOut() }
            }
        }
        .padding(12)
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoadingRepos && model.repos.isEmpty {
            spinner("Loading repositories…")
        } else if model.syncStatus == "Cloning…" || model.syncStatus == "Pulling…" {
            spinner("\(model.syncStatus)")
        } else {
            List {
                if isSheet, !model.connectedRepos.isEmpty {
                    Section("Connected") {
                        ForEach(model.connectedRepos) { connectedRow($0) }
                    }
                }
                if let last = lastUsed {
                    Section("Last Used") { repoRow(last) }
                }
                Section(isSheet ? "Add a Repository" : (lastUsed != nil ? "All Repositories" : "Repositories")) {
                    ForEach(reposToShow) { repoRow($0) }
                }
            }
            .searchable(text: $search, placement: .toolbar, prompt: "Filter repositories")
            .overlay {
                if let error = model.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red).padding()
                }
            }
        }
    }

    /// The last-used repo, shown pinned on top — but only when it isn't already
    /// connected and we're not filtering.
    private var lastUsed: GitHubRepo? {
        guard search.isEmpty, let last = model.lastUsedRepo else { return nil }
        return model.connectedRepos.contains { $0.id == last.fullName } ? nil : last
    }

    private var reposToShow: [GitHubRepo] {
        guard let last = lastUsed?.fullName else { return filtered }
        return filtered.filter { $0.fullName != last }
    }

    private func connectedRow(_ connected: ConnectedRepo) -> some View {
        HStack(spacing: 8) {
            Image(systemName: connected.repo.isPrivate ? "lock.fill" : "book.closed")
                .foregroundStyle(.secondary).frame(width: 16)
            Text(connected.repo.fullName)
            Spacer()
            Button {
                model.disconnectRepo(connected)
            } label: {
                Label("Disconnect", systemImage: "minus.circle.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("Disconnect this repository")
        }
    }

    private func repoRow(_ repo: GitHubRepo) -> some View {
        Button {
            Task { await model.openRepo(repo) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: repo.isPrivate ? "lock.fill" : "book.closed")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(repo.fullName)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func spinner(_ label: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(label).font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
