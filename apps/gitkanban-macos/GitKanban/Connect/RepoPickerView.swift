import GitKit
import SwiftUI

/// Pick a repository to open. Tapping a repo clones it into the app's own checkout.
struct RepoPickerView: View {
    @Environment(AppModel.self) private var model
    @State private var search = ""

    private var filtered: [GitHubRepo] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.repos }
        return model.repos.filter { $0.fullName.localizedCaseInsensitiveContains(query) }
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
                Text("Choose a repository").font(.headline)
                if let login = model.login {
                    Text("Signed in as \(login)").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Sign out") { model.signOut() }
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
                if search.isEmpty, let last = model.lastUsedRepo {
                    Section("Last Used") { repoRow(last) }
                }
                Section(search.isEmpty && model.lastUsedRepo != nil ? "All Repositories" : "Repositories") {
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

    private var reposToShow: [GitHubRepo] {
        guard search.isEmpty, let last = model.lastUsedRepo?.fullName else { return filtered }
        return filtered.filter { $0.fullName != last }
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
