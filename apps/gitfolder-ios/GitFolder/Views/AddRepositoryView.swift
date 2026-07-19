import GitPontCore
import SwiftUI

/// Pick a repository from the connected account to add to the home list. Excludes
/// repos already added. Tapping one adds and opens it.
struct AddRepositoryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var available: [GitRepository] {
        let added = Set(model.addedRepos.map(\.id))
        let notAdded = model.repos.filter { !added.contains(model.fullName($0)) }
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return notAdded }
        return notAdded.filter { model.fullName($0).localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        Group {
            if model.isLoadingRepos && model.repos.isEmpty {
                ProgressView("Loading repositories…")
            } else {
                List(available, id: \.reference.name) { repo in
                    Button {
                        model.addRepo(repo)
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: repo.isPrivate ? "lock.fill" : "book.closed")
                                .foregroundStyle(.secondary).frame(width: 20)
                            Text(model.fullName(repo)).foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "plus.circle").foregroundStyle(.tint)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .searchable(text: $search, prompt: "Filter repositories")
                .refreshable { await model.loadRepos() }
                .overlay {
                    if available.isEmpty && !model.isLoadingRepos {
                        ContentUnavailableView("Nothing to add", systemImage: "checkmark.circle",
                                               description: Text("Every repository is already added."))
                    }
                }
            }
        }
        .navigationTitle("Add Repository")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .task { if model.repos.isEmpty { await model.loadRepos() } }
    }
}
