import GitKit
import SwiftUI
import UniformTypeIdentifiers

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
        .onDrop(of: [.text], isTargeted: $isDropTargeted) { providers in
            guard isLane, let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                guard let id = object as? String else { return }
                Task { @MainActor in await model.moveCard(cardID: id, to: column.lane) }
            }
            return true
        }
    }
}

/// Horizontal lane carousel: the board snaps a lane toward the centre; the focused
/// lane and its immediate neighbours are wide, the rest narrow. Width (not height)
/// spring-animates when the focused lane changes while scrolling.
private struct LanesCarousel: View {
    let columns: [Column]

    private let base: CGFloat = 300
    private let spacing: CGFloat = 16

    var body: some View {
        GeometryReader { outer in
            let viewport = outer.size.width
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(Array(columns.enumerated()), id: \.element.id) { index, column in
                        let color = column.lane.folder.isEmpty ? Color.gray : LaneColor.at(index)
                        ColumnView(column: column, width: base, laneColor: color)
                            .visualEffect { content, proxy in
                                content.scaleEffect(
                                    laneScale(frame: proxy.frame(in: .scrollView(axis: .horizontal)),
                                              viewport: viewport),
                                    anchor: .top
                                )
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
    }
}

/// 1.0 when a lane is fully inside the scroll viewport; shrinks toward 0.5 as it
/// scrolls off either edge. So the lanes that fit (which depends on the window
/// width) stay in focus, and the first/last are in focus at the scroll ends.
private func laneScale(frame: CGRect, viewport: CGFloat) -> CGFloat {
    let overflow = max(max(0, -frame.minX), max(0, frame.maxX - viewport))
    let width = frame.width > 0 ? frame.width : 1
    return 1 - min(1, overflow / width) * 0.5
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
        .opacity(model.draggingCardID == card.fields.id ? 0.3 : 1)
        .onTapGesture { model.selectedCard = card }
        .onDrag {
            model.draggingCardID = card.fields.id
            return NSItemProvider(object: card.fields.id as NSString)
        }
        .contextMenu {
            Button("Open") { model.selectedCard = card }
            if let lanes = model.board?.config.lanes, !lanes.isEmpty {
                Menu("Move to") {
                    ForEach(lanes, id: \.id) { lane in
                        Button(lane.name) {
                            Task { await model.moveCard(cardID: card.fields.id, to: lane) }
                        }
                    }
                }
            }
            Divider()
            Button("Delete", role: .destructive) {
                Task { await model.deleteCard(cardID: card.fields.id) }
            }
        }
    }

    private var displayTitle: String {
        card.fields.title.isEmpty ? card.fields.id : card.fields.title
    }
}
