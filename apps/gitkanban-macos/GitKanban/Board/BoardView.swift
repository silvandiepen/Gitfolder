import AppKit
import GitKit
import SwiftUI
import UniformTypeIdentifiers

/// Renders the selected project's board: a filter/search bar on top, then the board
/// in the current view mode (horizontal lanes with a dockable backlog, or a grouped
/// list). Cards can be reordered and moved between lanes by dragging.
struct BoardView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Binding var showNewProject: Bool

    private var hasProjects: Bool { !(model.workspace?.projects.isEmpty ?? true) }

    /// Pipeline (non-backlog) lane columns with filters applied, plus a trailing
    /// "Uncategorised" column when there are stray cards.
    private func laneColumns(_ board: LoadedBoard) -> [Column] {
        var columns = board.columns
            .filter { !$0.lane.isBacklog }
            .map { filtered($0) }
        let uncategorised = board.uncategorised.filter(model.matchesFilters)
        if !uncategorised.isEmpty {
            columns.append(Column(
                lane: Lane(id: "_uncategorised", name: "Uncategorised", folder: "", status: ""),
                cards: uncategorised
            ))
        }
        return columns
    }

    /// The backlog lane columns, filters applied.
    private func backlogColumns(_ board: LoadedBoard) -> [Column] {
        board.columns.filter { $0.lane.isBacklog }.map { filtered($0) }
    }

    private func filtered(_ column: Column) -> Column {
        Column(lane: column.lane, cards: column.cards.filter(model.matchesFilters))
    }

    var body: some View {
        @Bindable var model = model
        return Group {
            if let board = model.board {
                VStack(spacing: 0) {
                    FilterBar()
                    Divider()
                    boardBody(board)
                }
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
        .overlay(alignment: .bottom) {
            if model.board != nil, !model.selectedCardIDs.isEmpty {
                SelectionBar(ids: Array(model.selectedCardIDs))
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.2), value: model.selectedCardIDs)
        .onChange(of: model.selectedCard) { _, card in
            if let card {
                openWindow(id: "task-detail", value: card.fields.id)
                model.selectedCard = nil
            }
        }
        .background {
            // Press N (with a lane selected) to add a task to that lane.
            Button("") {
                if let id = model.selectedLaneID,
                   let lane = model.board?.config.lanes.first(where: { $0.id == id }) {
                    model.newTaskLane = lane
                }
            }
            .keyboardShortcut(KeyEquivalent("n"), modifiers: [])
            .opacity(0)
            .accessibilityHidden(true)
        }
        .sheet(item: $model.newTaskLane) { lane in
            NewTaskSheet(lane: lane).environment(model)
        }
        .sheet(isPresented: $model.isShowingSearch) {
            SearchSheet().environment(model)
        }
    }

    @ViewBuilder
    private func boardBody(_ board: LoadedBoard) -> some View {
        let lanes = laneColumns(board)
        let backlog = backlogColumns(board)
        switch model.boardViewMode {
        case .list:
            BoardListView(columns: lanes + backlog)
        case .lanes:
            if backlog.isEmpty {
                LanesCarousel(columns: lanes)
            } else {
                switch model.backlogPlacement {
                case .bottom:
                    VStack(spacing: 0) {
                        LanesCarousel(columns: lanes)
                        Divider()
                        BacklogPanel(columns: backlog, placement: .bottom)
                    }
                case .right:
                    HStack(spacing: 0) {
                        LanesCarousel(columns: lanes)
                        Divider()
                        BacklogPanel(columns: backlog, placement: .right)
                    }
                }
            }
        }
    }
}

// MARK: - Selection bar

/// A floating bar shown while cards are multi-selected: the count, bulk actions, and
/// a clear button. Mirrors the right-click context menu for discoverability.
private struct SelectionBar: View {
    @Environment(AppModel.self) private var model
    let ids: [String]

    private var lanes: [Lane] { model.board?.config.lanes ?? [] }
    private var users: [User] { model.board?.config.users ?? [] }

    var body: some View {
        HStack(spacing: 12) {
            Text("\(ids.count) selected")
                .font(.callout.weight(.medium))

            if !lanes.isEmpty {
                Menu {
                    ForEach(lanes, id: \.id) { lane in
                        Button(lane.name) {
                            Task { await model.moveCards(ids: ids, to: lane) }
                        }
                    }
                } label: {
                    Label("Move", systemImage: "arrow.right.square")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            if !users.isEmpty {
                Menu {
                    Button("Unassigned") { Task { await model.assignCards(ids: ids, assignee: nil) } }
                    Divider()
                    ForEach(users, id: \.id) { user in
                        Button(user.name ?? user.id) {
                            Task { await model.assignCards(ids: ids, assignee: user.id) }
                        }
                    }
                } label: {
                    Label("Assign", systemImage: "person.crop.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            Button(role: .destructive) {
                Task { await model.deleteCards(ids: ids) }
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Divider().frame(height: 16)

            Button("Clear") { model.clearSelection() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(.quaternary, lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
    }
}

// MARK: - Colours

/// The colour for a lane: backlog is slate, uncategorised is gray, otherwise the
/// palette colour for the lane's position in the config (stable across views).
private func resolveLaneColor(_ lane: Lane, config: EffectiveConfig?) -> Color {
    if lane.isBacklog { return Color(red: 0.45, green: 0.50, blue: 0.58) }
    if lane.folder.isEmpty { return .gray }
    if let index = config?.lanes.firstIndex(where: { $0.id == lane.id }) { return LaneColor.at(index) }
    return .secondary
}

// MARK: - Shared card actions

@MainActor @ViewBuilder
private func cardContextMenu(for card: Card, model: AppModel) -> some View {
    let selection = model.selectedCardIDs
    let isBulk = selection.contains(card.fields.id) && selection.count > 1
    let lanes = model.board?.config.lanes ?? []
    let users = model.board?.config.users ?? []
    let targets = isBulk ? Array(selection) : [card.fields.id]

    if isBulk {
        Section("\(targets.count) tasks selected") {
            moveMenu(targets: targets, lanes: lanes, model: model)
            assignMenu(targets: targets, users: users, model: model)
            Button("Delete \(targets.count) Tasks", role: .destructive) {
                Task { await model.deleteCards(ids: targets) }
            }
            Button("Clear Selection") { model.clearSelection() }
        }
    } else {
        Button("Open") { model.selectedCard = card }
        moveMenu(targets: targets, lanes: lanes, model: model)
        assignMenu(targets: targets, users: users, model: model)
        Divider()
        Button("Delete", role: .destructive) {
            Task { await model.deleteCard(cardID: card.fields.id) }
        }
    }
}

@MainActor @ViewBuilder
private func moveMenu(targets: [String], lanes: [Lane], model: AppModel) -> some View {
    if !lanes.isEmpty {
        Menu(targets.count > 1 ? "Move \(targets.count) to" : "Move to") {
            ForEach(lanes, id: \.id) { lane in
                Button(lane.name) {
                    Task {
                        if targets.count > 1 { await model.moveCards(ids: targets, to: lane) }
                        else { await model.moveCard(cardID: targets[0], to: lane) }
                    }
                }
            }
        }
    }
}

@MainActor @ViewBuilder
private func assignMenu(targets: [String], users: [User], model: AppModel) -> some View {
    if !users.isEmpty {
        Menu(targets.count > 1 ? "Assign \(targets.count) to" : "Assign to") {
            Button("Unassigned") { Task { await model.assignCards(ids: targets, assignee: nil) } }
            Divider()
            ForEach(users, id: \.id) { user in
                Button(user.name ?? user.id) {
                    Task { await model.assignCards(ids: targets, assignee: user.id) }
                }
            }
        }
    }
}

/// Single click selects (⌘-click toggles multi-selection); it does not open.
@MainActor
private func handleCardSelect(_ card: Card, model: AppModel) {
    if NSEvent.modifierFlags.contains(.command) {
        model.toggleSelection(card.fields.id)
    } else {
        model.selectedCardIDs = [card.fields.id]
    }
}

/// Double click opens the card's detail window.
@MainActor
private func handleCardOpen(_ card: Card, model: AppModel) {
    model.selectedCard = card
}

/// Load a dragged card id from a drop and hand it to `action`.
private func handleCardDrop(_ providers: [NSItemProvider], _ action: @escaping @MainActor (String) -> Void) -> Bool {
    guard let provider = providers.first else { return false }
    _ = provider.loadObject(ofClass: NSString.self) { object, _ in
        guard let id = object as? String else { return }
        Task { @MainActor in action(id) }
    }
    return true
}

// MARK: - Lane column

private struct ColumnView: View {
    @Environment(AppModel.self) private var model
    let column: Column
    var width: CGFloat = 300
    @State private var isDropTargeted = false

    private var isLane: Bool { !column.lane.folder.isEmpty }
    private var laneColor: Color { resolveLaneColor(column.lane, config: model.board?.config) }
    private var isSelected: Bool { model.selectedLaneID == column.lane.id }

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
                CardCell(card: card, onReorder: isLane ? { dragged in
                    Task { await model.reorderCard(cardID: dragged, toLane: column.lane, beforeCardID: card.fields.id) }
                } : nil)
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
                .stroke(isDropTargeted ? laneColor : (isSelected ? laneColor.opacity(0.85) : laneColor.opacity(0.30)),
                        lineWidth: (isDropTargeted || isSelected) ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture { if isLane { model.selectedLaneID = column.lane.id } }
        .onDrop(of: [.text], isTargeted: $isDropTargeted) { providers in
            guard isLane else { return false }
            return handleCardDrop(providers) { id in
                Task { await model.reorderCard(cardID: id, toLane: column.lane, beforeCardID: nil) }
            }
        }
    }
}

/// Horizontal lane carousel: the board snaps a lane toward the centre; the focused
/// lane and its immediate neighbours are wide, the rest narrow. Width (not height)
/// spring-animates when the focused lane changes while scrolling.
private struct LanesCarousel: View {
    @Environment(AppModel.self) private var model
    let columns: [Column]

    private let base: CGFloat = 300
    private let spacing: CGFloat = 16

    @State private var anchorID: String?
    @State private var edgeDir = 0
    @State private var scrollTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { outer in
            let viewport = outer.size.width
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: spacing) {
                        ForEach(columns) { column in
                            ColumnView(column: column, width: base)
                                .id(column.id)
                                .visualEffect { content, proxy in
                                    content.scaleEffect(
                                        laneScale(frame: proxy.frame(in: .scrollView(axis: .horizontal)),
                                                  viewport: viewport),
                                        anchor: .top
                                    )
                                }
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .scrollPosition(id: $anchorID, anchor: .leading)
                .overlay(alignment: .leading) { edgeZone(-1, proxy: proxy) }
                .overlay(alignment: .trailing) { edgeZone(1, proxy: proxy) }
            }
        }
    }

    /// A thin drop zone at an edge that auto-scrolls the board while a card is
    /// dragged over it (so you can drag a task across off-screen lanes).
    private func edgeZone(_ dir: Int, proxy: ScrollViewProxy) -> some View {
        Color.clear
            .frame(width: 46).frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .allowsHitTesting(model.draggingCardID != nil)
            .onDrop(of: [.text], isTargeted: Binding(
                get: { edgeDir == dir },
                set: { active in setEdge(active ? dir : 0, proxy: proxy) }
            )) { _ in false }
    }

    private func setEdge(_ dir: Int, proxy: ScrollViewProxy) {
        guard edgeDir != dir else { return }
        edgeDir = dir
        scrollTask?.cancel()
        guard dir != 0 else { return }
        scrollTask = Task { @MainActor in
            while !Task.isCancelled && edgeDir == dir {
                step(dir, proxy: proxy)
                try? await Task.sleep(for: .milliseconds(180))
            }
        }
    }

    private func step(_ dir: Int, proxy: ScrollViewProxy) {
        let ids = columns.map(\.id)
        guard !ids.isEmpty else { return }
        let current = anchorID.flatMap { ids.firstIndex(of: $0) } ?? (dir < 0 ? 0 : ids.count - 1)
        let next = max(0, min(ids.count - 1, current + dir))
        withAnimation(.easeInOut(duration: 0.18)) { proxy.scrollTo(ids[next], anchor: .leading) }
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

// MARK: - Backlog panel (always a list; docks bottom or right)

private struct BacklogPanel: View {
    @Environment(AppModel.self) private var model
    let columns: [Column]
    let placement: BacklogPlacement

    @State private var expanded = true
    @State private var isDropTargeted = false

    private var lane: Lane? { columns.first?.lane }
    private var cards: [Card] { columns.flatMap(\.cards) }
    private var color: Color { lane.map { resolveLaneColor($0, config: model.board?.config) } ?? .secondary }

    var body: some View {
        VStack(spacing: 0) {
            header
            if expanded {
                if cards.isEmpty {
                    Text("No backlog items yet.")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(cards) { card in
                                CardRow(card: card, onReorder: lane.map { l in
                                    { dragged in
                                        Task { await model.reorderCard(cardID: dragged, toLane: l, beforeCardID: card.fields.id) }
                                    }
                                })
                                .padding(.horizontal, 14).padding(.vertical, 6)
                                Divider().padding(.leading, 14)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: placement == .right ? 320 : nil)
        .frame(maxWidth: placement == .right ? nil : .infinity,
               maxHeight: placement == .bottom ? (expanded ? 260 : nil) : .infinity,
               alignment: .top)
        .background(isDropTargeted ? AnyShapeStyle(color.opacity(0.10)) : AnyShapeStyle(.quaternary.opacity(0.14)))
        .onDrop(of: [.text], isTargeted: $isDropTargeted) { providers in
            guard let lane, !lane.folder.isEmpty else { return false }
            return handleCardDrop(providers) { id in
                Task { await model.reorderCard(cardID: id, toLane: lane, beforeCardID: nil) }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.snappy(duration: 0.2)) { expanded.toggle() }
            } label: {
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    .frame(width: 16)
            }
            .buttonStyle(.plain)

            Image(systemName: "tray.full").foregroundStyle(color)
            Text(lane?.name ?? "Backlog").font(.subheadline).fontWeight(.semibold)
            Text("\(cards.count)")
                .font(.caption).fontWeight(.medium)
                .foregroundStyle(color)
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background(color.opacity(0.16), in: Capsule())

            Spacer()

            Button {
                model.toggleBacklogPlacement()
            } label: {
                Image(systemName: placement == .bottom ? "rectangle.trailinghalf.inset.filled" : "rectangle.bottomthird.inset.filled")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(placement == .bottom ? "Dock backlog to the right" : "Dock backlog to the bottom")

            if let lane, !lane.folder.isEmpty {
                Button {
                    model.newTaskLane = lane
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Add to backlog")
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
}

// MARK: - List view (grouped by lane; reorder + cross-lane by drag)

private struct BoardListView: View {
    let columns: [Column]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(columns) { column in
                    LaneListSection(column: column)
                }
            }
            .padding(.vertical, 6)
        }
    }
}

private struct LaneListSection: View {
    @Environment(AppModel.self) private var model
    let column: Column
    @State private var isDropTargeted = false

    private var isLane: Bool { !column.lane.folder.isEmpty }
    private var color: Color { resolveLaneColor(column.lane, config: model.board?.config) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(column.lane.name).font(.subheadline).fontWeight(.semibold)
                Text("\(column.cards.count)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if isLane {
                    Button { model.newTaskLane = column.lane } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .help("Add task")
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 6)
            .background(color.opacity(0.08))

            if column.cards.isEmpty {
                Text("No tasks")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal, 16).padding(.vertical, 8)
            } else {
                ForEach(column.cards) { card in
                    CardRow(card: card, onReorder: isLane ? { dragged in
                        Task { await model.reorderCard(cardID: dragged, toLane: column.lane, beforeCardID: card.fields.id) }
                    } : nil)
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    Divider().padding(.leading, 16)
                }
            }
        }
        .background(isDropTargeted ? color.opacity(0.10) : Color.clear)
        .onDrop(of: [.text], isTargeted: $isDropTargeted) { providers in
            guard isLane else { return false }
            return handleCardDrop(providers) { id in
                Task { await model.reorderCard(cardID: id, toLane: column.lane, beforeCardID: nil) }
            }
        }
    }
}

/// A single-line card row (list view + backlog). Draggable; if `onReorder` is set it
/// also accepts drops to insert the dragged card before it.
private struct CardRow: View {
    @Environment(AppModel.self) private var model
    let card: Card
    var onReorder: ((String) -> Void)? = nil

    @State private var isDropTargeted = false

    private var priorities: [Priority] { model.board?.config.priorities ?? [] }
    private var isSelected: Bool { model.selectedCardIDs.contains(card.fields.id) }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.35))
            if let priority = card.fields.priority,
               let color = PriorityColor.color(for: priority, in: priorities) {
                Text(priority)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(color.opacity(0.16), in: Capsule())
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(displayTitle).font(.callout).lineLimit(1)
                if !card.fields.id.isEmpty {
                    Text(card.fields.id).font(.caption2.monospaced()).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if let type = card.fields.type {
                Text(type).font(.caption2).foregroundStyle(.secondary)
            }
            if let assignee = card.fields.assignee {
                Text("@\(assignee)").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.10) : Color.clear)
        .overlay(alignment: .top) {
            if isDropTargeted {
                Rectangle().fill(Color.accentColor).frame(height: 2)
            }
        }
        .contentShape(Rectangle())
        .opacity(model.draggingCardID == card.fields.id ? 0.3 : 1)
        .onTapGesture(count: 2) { handleCardOpen(card, model: model) }
        .onTapGesture(count: 1) { handleCardSelect(card, model: model) }
        .onDrag {
            model.draggingCardID = card.fields.id
            return NSItemProvider(object: card.fields.id as NSString)
        }
        .modifier(ReorderDrop(enabled: onReorder != nil, isTargeted: $isDropTargeted) { providers in
            handleCardDrop(providers) { id in onReorder?(id) }
        })
        .contextMenu { cardContextMenu(for: card, model: model) }
    }

    private var displayTitle: String {
        card.fields.title.isEmpty ? card.fields.id : card.fields.title
    }
}

// MARK: - Card cell (lanes + backlog card layout)

private struct CardCell: View {
    @Environment(AppModel.self) private var model
    let card: Card
    var onReorder: ((String) -> Void)? = nil

    @State private var isDropTargeted = false

    private var priorities: [Priority] { model.board?.config.priorities ?? [] }
    private var isSelected: Bool { model.selectedCardIDs.contains(card.fields.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                Text(displayTitle).font(.callout).lineLimit(3)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
            }
            HStack(spacing: 6) {
                if let priority = card.fields.priority,
                   let color = PriorityColor.color(for: priority, in: priorities) {
                    Text(priority)
                        .font(.caption2).fontWeight(.medium)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(color.opacity(0.18), in: Capsule())
                        .foregroundStyle(color)
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
        .overlay(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(isSelected ? 0.12 : 0)))
        .overlay(alignment: .top) {
            if isDropTargeted {
                Rectangle().fill(Color.accentColor).frame(height: 2).padding(.horizontal, 4)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.25),
                        lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle())
        .opacity(model.draggingCardID == card.fields.id ? 0.3 : 1)
        .onTapGesture(count: 2) { handleCardOpen(card, model: model) }
        .onTapGesture(count: 1) { handleCardSelect(card, model: model) }
        .onDrag {
            model.draggingCardID = card.fields.id
            return NSItemProvider(object: card.fields.id as NSString)
        }
        .modifier(ReorderDrop(enabled: onReorder != nil, isTargeted: $isDropTargeted) { providers in
            handleCardDrop(providers) { id in onReorder?(id) }
        })
        .contextMenu { cardContextMenu(for: card, model: model) }
    }

    private var displayTitle: String {
        card.fields.title.isEmpty ? card.fields.id : card.fields.title
    }
}

/// Attaches a reorder drop target only when enabled, so non-reorderable cards (e.g.
/// uncategorised) don't intercept drops.
private struct ReorderDrop: ViewModifier {
    let enabled: Bool
    @Binding var isTargeted: Bool
    let onDrop: ([NSItemProvider]) -> Bool

    func body(content: Content) -> some View {
        if enabled {
            content.onDrop(of: [.text], isTargeted: $isTargeted, perform: onDrop)
        } else {
            content
        }
    }
}
