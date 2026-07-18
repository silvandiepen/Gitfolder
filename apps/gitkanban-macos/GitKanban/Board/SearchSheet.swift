import GitKit
import SwiftUI

/// A full-board search sheet: type to match cards by title, id, body, assignee, or
/// type across every lane (and the backlog). Selecting a result opens its detail.
struct SearchSheet: View {
    @Environment(AppModel.self) private var model
    @FocusState private var searchFocused: Bool

    /// A card paired with the lane it lives in, for display + navigation.
    private struct Hit: Identifiable {
        let card: Card
        let lane: Lane
        var id: String { card.id }
    }

    private var lanesByStatus: [String: Lane] {
        Dictionary(uniqueKeysWithValues: (model.board?.config.lanes ?? []).map { ($0.status, $0) })
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
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search tasks by title, id, body, assignee…", text: $model.searchText)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($searchFocused)
                if !model.searchText.isEmpty {
                    Button {
                        model.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Button("Done") { model.isShowingSearch = false }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)
            Divider()

            if hits.isEmpty {
                ContentUnavailableView(
                    model.searchText.isEmpty ? "Search the board" : "No matches",
                    systemImage: "magnifyingglass",
                    description: Text(model.searchText.isEmpty
                        ? "Type to find tasks across every lane and the backlog."
                        : "No tasks match “\(model.searchText)”.")
                )
                .frame(maxHeight: .infinity)
            } else {
                List(hits) { hit in
                    Button {
                        model.selectedCard = hit.card
                        model.isShowingSearch = false
                    } label: {
                        HitRow(hit: hit, laneColor: LaneColor.forStatus(hit.lane.status, in: model.board?.config.lanes ?? []))
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 620, height: 520)
        .onAppear { searchFocused = true }
    }

    private struct HitRow: View {
        @Environment(AppModel.self) private var model
        let hit: Hit
        let laneColor: Color

        private var priorities: [Priority] { model.board?.config.priorities ?? [] }

        var body: some View {
            HStack(spacing: 10) {
                if let priority = hit.card.fields.priority,
                   let color = PriorityColor.color(for: priority, in: priorities) {
                    Text(priority)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(color.opacity(0.16), in: Capsule())
                        .foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(hit.card.fields.title.isEmpty ? hit.card.fields.id : hit.card.fields.title)
                        .font(.callout).lineLimit(1)
                    HStack(spacing: 6) {
                        Text(hit.card.fields.id).font(.caption2.monospaced())
                        if let assignee = hit.card.fields.assignee { Text("@\(assignee)").font(.caption2) }
                    }
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                HStack(spacing: 5) {
                    Circle().fill(laneColor).frame(width: 7, height: 7)
                    Text(hit.lane.name).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
    }
}
