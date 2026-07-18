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

/// Horizontal lane carousel: the board snaps a lane toward the centre; the focused
/// lane and its immediate neighbours are wide, the rest narrow. Width (not height)
/// spring-animates when the focused lane changes while scrolling.
private struct LanesCarousel: View {
    let columns: [Column]
    @State private var focusedID: String?

    private let wide: CGFloat = 320
    private let mid: CGFloat = 240
    private let narrow: CGFloat = 148
    private let spacing: CGFloat = 16

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: spacing) {
                ForEach(columns) { column in
                    ColumnView(column: column, width: width(for: column))
                        .id(column.id)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: focusedID)
        }
        .scrollPosition(id: $focusedID, anchor: .center)
        .scrollTargetBehavior(.viewAligned)
        .onAppear { if focusedID == nil { focusedID = columns.first?.id } }
        .onChange(of: columns.map(\.id)) { _, ids in
            if focusedID == nil || !ids.contains(focusedID!) { focusedID = ids.first }
        }
    }

    private func width(for column: Column) -> CGFloat {
        guard let focusedID,
              let focusedIndex = columns.firstIndex(where: { $0.id == focusedID }),
              let index = columns.firstIndex(where: { $0.id == column.id }) else { return wide }
        switch abs(index - focusedIndex) {
        case 0, 1: return wide
        case 2: return mid
        default: return narrow
        }
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
