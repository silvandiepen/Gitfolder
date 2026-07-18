import GitKit
import SwiftUI

/// Full-board search: match cards by title, id, body, assignee, or type across every
/// lane. Selecting a result opens it for editing.
struct SearchSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private struct Hit: Identifiable {
        let card: Card
        let lane: Lane
        var id: String { card.id }
    }

    private var hits: [Hit] {
        guard let board = model.board else { return [] }
        var out: [Hit] = []
        for column in board.columns {
            for card in column.cards { out.append(Hit(card: card, lane: column.lane)) }
        }
        let query = model.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return out }
        return out.filter { hit in
            let f = hit.card.fields
            return [f.title, f.id, f.type ?? "", f.assignee ?? "", hit.card.body]
                .contains { $0.lowercased().contains(query) }
        }
    }

    var body: some View {
        @Bindable var model = model
        return NavigationStack {
            Group {
                if hits.isEmpty {
                    ContentUnavailableView(
                        model.searchText.isEmpty ? "Search the board" : "No matches",
                        systemImage: "magnifyingglass",
                        description: Text(model.searchText.isEmpty
                            ? "Find tasks across every lane."
                            : "No tasks match “\(model.searchText)”.")
                    )
                } else {
                    List(hits) { hit in
                        Button {
                            dismiss()
                            model.selectedCard = hit.card
                        } label: {
                            HStack(spacing: 10) {
                                if let priority = hit.card.fields.priority,
                                   let color = PriorityPalette.color(priority, model.board?.config.priorities ?? []) {
                                    Text(priority)
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 6).padding(.vertical, 1)
                                        .background(color.opacity(0.16), in: Capsule())
                                        .foregroundStyle(color)
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(hit.card.fields.title.isEmpty ? hit.card.fields.id : hit.card.fields.title)
                                        .font(.body).lineLimit(1)
                                    Text(hit.lane.name).font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $model.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Title, id, body, assignee…")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
