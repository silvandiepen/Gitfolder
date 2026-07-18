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
    var laneColor: Color = .secondary
    @State private var isDropTargeted = false

    private var isLane: Bool { !column.lane.folder.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Circle().fill(laneColor).frame(width: 9, height: 9)
                Text(column.lane.name).font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text("\(column.cards.count)")
                    .font(.caption).fontWeight(.medium)
                    .foregroundStyle(laneColor)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(laneColor.opacity(0.16), in: Capsule())
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
        .background(isDropTargeted ? AnyShapeStyle(laneColor.opacity(0.14)) : AnyShapeStyle(.quaternary.opacity(0.4)), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isDropTargeted ? laneColor : laneColor.opacity(0.30),
                        lineWidth: isDropTargeted ? 2 : 1)
        )
        .dropDestination(for: String.self) { ids, _ in
            guard isLane, let id = ids.first else { return false }
            Task { await model.moveCard(cardID: id, to: column.lane) }
            return true
        } isTargeted: { isDropTargeted = $0 }
    }
}

/// Horizontal lane carousel: the board snaps a lane toward the centre; the focused
/// lane and its immediate neighbours are wide, the rest narrow. Width (not height)
/// spring-animates when the focused lane changes while scrolling.
private struct LanesCarousel: View {
    let columns: [Column]
    @State private var focusedID: String?

    private let base: CGFloat = 300
    private let spacing: CGFloat = 16

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: spacing) {
                ForEach(Array(columns.enumerated()), id: \.element.id) { index, column in
                    let scale = scale(for: column)
                    let color = column.lane.folder.isEmpty ? Color.gray : LaneColor.at(index)
                    ColumnView(column: column, width: base, laneColor: color)
                        .scaleEffect(scale, anchor: .top)
                        // Reclaim the horizontal gap the scale leaves, so non-focused
                        // lanes sit narrower rather than shrinking in place.
                        .padding(.horizontal, -base * (1 - scale) / 2)
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

    /// The focused lane and its two neighbours stay full size (≈3 in focus); the
    /// rest shrink, and further-out lanes shrink more.
    private func scale(for column: Column) -> CGFloat {
        guard let focusedID,
              let focusedIndex = columns.firstIndex(where: { $0.id == focusedID }),
              let index = columns.firstIndex(where: { $0.id == column.id }) else { return 1 }
        switch abs(index - focusedIndex) {
        case 0, 1: return 1.0
        case 2: return 0.66
        default: return 0.46
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
        .draggable(card.fields.id)
    }

    private var displayTitle: String {
        card.fields.title.isEmpty ? card.fields.id : card.fields.title
    }
}
