import GitKit
import SwiftUI

/// Renders the selected project's board: its lanes as columns, plus any
/// uncategorised cards. Tapping a card opens its detail sheet.
struct BoardView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        return Group {
            if let board = model.board {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(board.columns) { column in
                            ColumnView(column: column)
                        }
                        if !board.uncategorised.isEmpty {
                            ColumnView(column: Column(
                                lane: Lane(id: "_uncategorised", name: "Uncategorised", folder: "", status: ""),
                                cards: board.uncategorised
                            ))
                        }
                    }
                    .padding(16)
                }
            } else {
                ContentUnavailableView(
                    "No project selected",
                    systemImage: "square.stack.3d.up",
                    description: Text("Pick a project from the sidebar.")
                )
            }
        }
        .frame(minWidth: 620, minHeight: 480)
        .sheet(item: $model.selectedCard) { card in
            CardDetailView(card: card).environment(model)
        }
    }
}

private struct ColumnView: View {
    let column: Column

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(column.lane.name).font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text("\(column.cards.count)").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(column.cards) { card in
                CardCell(card: card)
            }
            Spacer(minLength: 0)
        }
        .frame(width: 260, alignment: .leading)
        .padding(10)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct CardCell: View {
    @Environment(AppModel.self) private var model
    let card: Card

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(displayTitle).font(.callout).lineLimit(3)
            HStack(spacing: 6) {
                if let priority = card.fields.priority {
                    Text(priority)
                        .font(.caption2).fontWeight(.medium)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(.tint.opacity(0.18), in: Capsule())
                }
                if let assignee = card.fields.assignee {
                    Text("@\(assignee)").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { model.selectedCard = card }
    }

    private var displayTitle: String {
        card.fields.title.isEmpty ? card.fields.id : card.fields.title
    }
}
