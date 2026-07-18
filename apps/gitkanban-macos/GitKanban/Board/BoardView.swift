import GitKit
import SwiftUI

struct BoardView: View {
    @Environment(BoardViewModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(model.columns) { column in
                        ColumnView(column: column)
                    }
                    if !model.uncategorised.isEmpty {
                        ColumnView(column: Column(
                            lane: Lane(id: "_uncategorised", name: "Uncategorised", folder: "", status: ""),
                            cards: model.uncategorised
                        ))
                    }
                }
                .padding(16)
            }
        }
        .frame(minWidth: 820, minHeight: 520)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(model.boardName).font(.headline)
            if let error = model.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red).lineLimit(1)
            }
            Spacer()
            Button("Open Folder…") { model.openFolder() }
        }
        .padding(12)
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
    }

    private var displayTitle: String {
        card.fields.title.isEmpty ? card.fields.id : card.fields.title
    }
}
