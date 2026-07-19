import GitPontCore
import SwiftUI

/// The account's repositories. Tapping one opens its file browser.
struct RepoListView: View {
    @Environment(AppModel.self) private var model
    @State private var search = ""

    private var filtered: [GitRepository] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return model.repos }
        return model.repos.filter { model.fullName($0).localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        Group {
            if model.isLoadingRepos && model.repos.isEmpty {
                ProgressView("Loading repositories…")
            } else {
                List(filtered, id: \.reference.name) { repo in
                    Button {
                        model.openRepo(repo)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: repo.isPrivate ? "lock.fill" : "book.closed")
                                .foregroundStyle(.secondary).frame(width: 20)
                            Text(model.fullName(repo)).foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                }
                .searchable(text: $search, prompt: "Filter repositories")
                .refreshable { await model.loadRepos() }
                .overlay {
                    if let error = model.errorMessage, model.repos.isEmpty {
                        ContentUnavailableView("Couldn't load repositories", systemImage: "exclamationmark.triangle", description: Text(error))
                    }
                }
            }
        }
        .navigationTitle("Repositories")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let login = model.connection?.login {
                        Text("Signed in as \(login)")
                    }
                    Button("Sign Out", role: .destructive) { model.signOut() }
                } label: {
                    Image(systemName: "person.crop.circle")
                }
            }
        }
    }
}
