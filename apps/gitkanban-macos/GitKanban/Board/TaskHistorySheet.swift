import GitKit
import SwiftUI

/// The commit history of a task's markdown file.
struct TaskHistorySheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let card: Card

    @State private var commits: [CommitInfo] = []
    @State private var loading = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("History").font(.headline)
                Text(card.fields.id).font(.caption.monospaced()).foregroundStyle(.secondary)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            .padding(14)
            Divider()

            if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if commits.isEmpty {
                ContentUnavailableView("No history yet", systemImage: "clock.arrow.circlepath")
            } else {
                List(commits) { commit in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(commit.message).font(.callout).lineLimit(2)
                        HStack(spacing: 10) {
                            Text(commit.id.prefix(7)).font(.caption.monospaced()).foregroundStyle(.secondary)
                            Text(commit.author).font(.caption).foregroundStyle(.secondary)
                            Text(commit.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(width: 560, height: 520)
        .task {
            commits = await model.fileHistory(for: card)
            loading = false
        }
    }
}
