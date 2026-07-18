import GitKit
import SwiftUI

/// Renders the selected project's board: its lanes as columns, plus any
/// uncategorised cards. Tapping a card opens its detail sheet.
struct BoardView: View {
    @Environment(AppModel.self) private var model
    @Binding var showNewProject: Bool

    private var hasProjects: Bool { !(model.workspace?.projects.isEmpty ?? true) }

    /// The board's lane columns, plus a trailing "Uncategorised" column when needed.
    private func allColumns(_ board: LoadedBoard) -> [Column] {
        var columns = board.columns
        if !board.uncategorised.isEmpty {
            columns.append(Column(
                lane: Lane(id: "_uncategorised", name: "Uncategorised", folder: "", status: ""),
                cards: board.uncategorised
            ))
        }
        return columns
    }

    var body: some View {
        @Bindable var model = model
        return Group {
            if let board = model.board {
                LanesCarousel(columns: allColumns(board))
            } else if !hasProjects {
                ProjectsEmptyState(onCreate: { showNewProject = true })
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
        .sheet(item: $model.newTaskLane) { lane in
            NewTaskSheet(lane: lane).environment(model)
        }
    }
}

private struct ColumnView: View {
    @Environment(AppModel.self) private var model
    let column: Column
    var width: CGFloat = 300

    private var isLane: Bool { !column.lane.folder.isEmpty }

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
            if isLane {
                Button {
                    model.newTaskLane = column.lane
                } label: {
                    Label("Add Task", systemImage: "plus")
                        .font(.caption).frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            }
            Spacer(minLength: 0)
        }
        .frame(width: width, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Horizontal lane carousel: fixed slots keep positions stable while each lane's
/// card width grows toward the viewport centre and shrinks toward the edges —
/// width animates, height stays constant.
private struct LanesCarousel: View {
    let columns: [Column]
    @State private var offset: CGFloat = 0

    private let slot: CGFloat = 320
    private let spacing: CGFloat = 14
    private let minWidth: CGFloat = 150
    private let maxWidth: CGFloat = 300

    var body: some View {
        GeometryReader { outer in
            let vp = outer.size.width
            let inset = max(16, vp / 2 - slot / 2)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(Array(columns.enumerated()), id: \.element.id) { index, column in
                        let center = inset + CGFloat(index) * (slot + spacing) + slot / 2 + offset
                        let focus = focusValue(distance: abs(center - vp / 2))
                        ColumnView(column: column, width: minWidth + (maxWidth - minWidth) * focus)
                            .frame(width: slot)
                            .opacity(0.55 + 0.45 * focus)
                    }
                }
                .padding(.horizontal, inset)
                .padding(.vertical, 16)
                .background(GeometryReader { g in
                    Color.clear.preference(key: LaneOffsetKey.self, value: g.frame(in: .named("lanes")).minX)
                })
            }
            .coordinateSpace(name: "lanes")
            .onPreferenceChange(LaneOffsetKey.self) { offset = $0 }
        }
    }

    private func focusValue(distance: CGFloat) -> CGFloat {
        let radius = (slot + spacing) * 1.3
        return min(1, max(0, 1.25 - distance / radius))
    }
}

private struct LaneOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
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
