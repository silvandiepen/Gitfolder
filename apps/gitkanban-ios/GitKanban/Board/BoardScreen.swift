import GitKit
import SwiftUI

/// The board for the active project, in either **lanes** (horizontal kanban) or
/// **list** mode. Backlog lanes are ordered last. Tap a card for its detail (rendered
/// description + edit), use a lane's ﹢ to add, and the toolbar to switch view, filter,
/// or search. Edits commit over the provider API (git-pont) and reload.
struct BoardScreen: View {
    @Environment(AppModel.self) private var model

    private var projects: [BoardProject] { model.workspace?.projects ?? [] }

    var body: some View {
        @Bindable var model = model
        return Group {
            if model.isLoadingBoard && model.board == nil {
                ProgressView("Loading board…")
            } else if let board = model.board {
                switch model.boardViewMode {
                case .lanes: LanesView(columns: displayColumns(board))
                case .list: ListBoardView(columns: displayColumns(board))
                }
            } else {
                ContentUnavailableView("No board", systemImage: "square.stack.3d.up",
                                       description: Text("This repo has no project boards."))
            }
        }
        .navigationTitle(model.selectedProject?.name ?? model.activeRepo?.reference.name ?? "Board")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) { savingBanner }
        .toolbar { toolbarContent }
        .sheet(item: $model.selectedCard) { card in CardDetailSheet(card: card).environment(model) }
        .sheet(item: $model.newTaskLane) { lane in NewTaskSheet(lane: lane).environment(model) }
        .sheet(isPresented: $model.isShowingSearch) { SearchSheet().environment(model) }
    }

    @ViewBuilder private var savingBanner: some View {
        if model.isSaving {
            HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Saving…").font(.caption) }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, 8)
        }
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { model.closeRepo() } label: {
                HStack(spacing: 2) { Image(systemName: "chevron.left"); Text("Repos") }
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            if model.boardViewMode == .list { EditButton() }
            layoutMenu
            Button { model.isShowingSearch = true } label: { Image(systemName: "magnifyingglass") }
            filterMenu
        }
    }

    private var layoutMenu: some View {
        @Bindable var model = model
        return Menu {
            Picker("View", selection: $model.boardViewMode) {
                Label("Lanes", systemImage: "rectangle.split.3x1").tag(BoardViewMode.lanes)
                Label("List", systemImage: "list.bullet").tag(BoardViewMode.list)
            }
        } label: {
            Image(systemName: model.boardViewMode == .lanes ? "rectangle.split.3x1" : "list.bullet")
        }
    }

    private var filterMenu: some View {
        @Bindable var model = model
        return Menu {
            if projects.count > 1 {
                Picker("Project", selection: Binding(
                    get: { model.selectedProject?.id ?? "" },
                    set: { id in if let p = projects.first(where: { $0.id == id }) { Task { await model.selectProject(p) } } }
                )) { ForEach(projects) { Text($0.name).tag($0.id) } }
            }
            Menu("Assignee") {
                Button("Anyone") { model.filterAssignee = nil }
                ForEach(assignees, id: \.self) { a in
                    Button { model.filterAssignee = a } label: { filterLabel(a, model.filterAssignee == a) }
                }
            }
            if !priorities.isEmpty {
                Menu("Priority") {
                    Button("Any") { model.filterPriority = nil }
                    ForEach(priorities, id: \.id) { p in
                        Button { model.filterPriority = p.id } label: { filterLabel(p.name ?? p.id, model.filterPriority == p.id) }
                    }
                }
            }
            if !types.isEmpty {
                Menu("Type") {
                    Button("Any") { model.filterType = nil }
                    ForEach(types, id: \.self) { t in
                        Button { model.filterType = t } label: { filterLabel(t, model.filterType == t) }
                    }
                }
            }
            if model.hasActiveFilters {
                Divider()
                Button("Clear Filters", role: .destructive) { model.clearFilters() }
            }
        } label: {
            Image(systemName: model.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
    }

    @ViewBuilder private func filterLabel(_ text: String, _ selected: Bool) -> some View {
        if selected { Label(text, systemImage: "checkmark") } else { Text(text) }
    }

    // MARK: Data

    private var config: EffectiveConfig? { model.board?.config }
    private var assignees: [String] {
        let fromConfig = config?.users.map(\.id) ?? []
        let fromCards = model.allCards.compactMap(\.fields.assignee)
        return Array(Set(fromConfig + fromCards)).sorted()
    }
    private var priorities: [Priority] { config?.priorities ?? [] }
    private var types: [String] {
        let fromConfig = config?.types ?? []
        let fromCards = model.allCards.compactMap(\.fields.type)
        return Array(Set(fromConfig + fromCards)).sorted()
    }

    /// Filtered columns ordered pipeline-lanes → backlog lanes → uncategorised.
    private func displayColumns(_ board: LoadedBoard) -> [Column] {
        let filtered = board.columns.map { Column(lane: $0.lane, cards: $0.cards.filter(model.matchesFilters)) }
        var cols = filtered.filter { !$0.lane.isBacklog } + filtered.filter { $0.lane.isBacklog }
        let uncategorised = board.uncategorised.filter(model.matchesFilters)
        if !uncategorised.isEmpty {
            cols.append(Column(
                lane: Lane(id: "_uncategorised", name: "Uncategorised", folder: "", status: ""),
                cards: uncategorised
            ))
        }
        return cols
    }
}

// MARK: - Lanes (horizontal kanban)

private struct LanesView: View {
    @Environment(AppModel.self) private var model
    let columns: [Column]

    var body: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(columns) { column in
                        LaneColumn(column: column, maxHeight: geo.size.height - 24)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
        }
    }
}

private struct LaneColumn: View {
    @Environment(AppModel.self) private var model
    let column: Column
    let maxHeight: CGFloat

    private var color: Color { laneColor(column.lane, model.board?.config ?? EffectiveConfig()) }
    private var isLane: Bool { !column.lane.folder.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Circle().fill(color).frame(width: 9, height: 9)
                Text(column.lane.name).font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text("\(column.cards.count)")
                    .font(.caption).fontWeight(.medium).foregroundStyle(color)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(color.opacity(0.16), in: Capsule())
            }
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(column.cards) { card in
                        LaneCardCell(card: card)
                    }
                    if isLane {
                        Button { model.newTaskLane = column.lane } label: {
                            Label("Add Task", systemImage: "plus")
                                .font(.caption).frame(maxWidth: .infinity).padding(.vertical, 8)
                        }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 300)
        .frame(maxHeight: maxHeight, alignment: .top)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.3), lineWidth: 1))
    }
}

private struct LaneCardCell: View {
    @Environment(AppModel.self) private var model
    let card: Card
    private var priorities: [Priority] { model.board?.config.priorities ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(card.fields.title.isEmpty ? card.fields.id : card.fields.title)
                .font(.callout).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 6) {
                if let p = card.fields.priority, let color = PriorityPalette.color(p, priorities) {
                    Text(p).font(.caption2.weight(.medium))
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(color.opacity(0.18), in: Capsule()).foregroundStyle(color)
                }
                if let a = card.fields.assignee {
                    Text("@\(a)").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { model.selectedCard = card }
        .contextMenu { cardMenu(card, model: model) }
    }
}

// MARK: - List

private struct ListBoardView: View {
    @Environment(AppModel.self) private var model
    let columns: [Column]

    var body: some View {
        List {
            ForEach(columns) { column in
                Section {
                    if column.cards.isEmpty {
                        Text("No tasks").font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(column.cards) { card in
                            Button { model.selectedCard = card } label: {
                                CardRow(card: card, priorities: model.board?.config.priorities ?? [])
                            }
                            .buttonStyle(.plain)
                        }
                        .onMove { indices, newOffset in
                            guard !column.lane.folder.isEmpty, !model.hasActiveFilters else { return }
                            var ids = column.cards.map { $0.fields.id }
                            ids.move(fromOffsets: indices, toOffset: newOffset)
                            Task { await model.reorderCards(in: column.lane, orderedIDs: ids) }
                        }
                        .onDelete { indices in
                            let doomed = indices.map { column.cards[$0] }
                            Task { for card in doomed { await model.deleteCard(card) } }
                        }
                    }
                } header: {
                    HStack(spacing: 7) {
                        Circle().fill(laneColor(column.lane, model.board?.config ?? EffectiveConfig()))
                            .frame(width: 8, height: 8)
                        Text(column.lane.name)
                        Text("\(column.cards.count)").foregroundStyle(.secondary)
                        Spacer()
                        if !column.lane.folder.isEmpty {
                            Button { model.newTaskLane = column.lane } label: { Image(systemName: "plus.circle") }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            if let project = model.selectedProject { await model.selectProject(project) }
        }
    }
}

struct CardRow: View {
    let card: Card
    let priorities: [Priority]

    var body: some View {
        HStack(spacing: 10) {
            if let priority = card.fields.priority,
               let color = PriorityPalette.color(priority, priorities) {
                Text(priority)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(color.opacity(0.16), in: Capsule())
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(card.fields.title.isEmpty ? card.fields.id : card.fields.title)
                    .font(.body).lineLimit(2)
                if !card.fields.id.isEmpty {
                    Text(card.fields.id).font(.caption2.monospaced()).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if let assignee = card.fields.assignee {
                Text("@\(assignee)").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

// MARK: - Shared card context menu

@MainActor @ViewBuilder
func cardMenu(_ card: Card, model: AppModel) -> some View {
    Button("Open") { model.selectedCard = card }
    if let lanes = model.board?.config.lanes, !lanes.isEmpty {
        Menu("Move to") {
            ForEach(lanes, id: \.id) { lane in
                Button(lane.name) { Task { await model.moveCard(card, to: lane) } }
            }
        }
    }
    Divider()
    Button("Delete", role: .destructive) { Task { await model.deleteCard(card) } }
}

// MARK: - Colours (local to iOS)

func laneColor(_ lane: Lane, _ config: EffectiveConfig) -> Color {
    if lane.isBacklog { return Color(red: 0.45, green: 0.50, blue: 0.58) }
    if lane.folder.isEmpty { return .gray }
    let palette: [Color] = [
        Color(red: 0.55, green: 0.36, blue: 0.96), Color(red: 0.23, green: 0.51, blue: 0.96),
        Color(red: 0.96, green: 0.62, blue: 0.09), Color(red: 0.91, green: 0.70, blue: 0.05),
        Color(red: 0.13, green: 0.77, blue: 0.37), Color(red: 0.09, green: 0.64, blue: 0.72),
    ]
    let index = config.lanes.firstIndex { $0.id == lane.id } ?? 0
    return palette[index % palette.count]
}

enum PriorityPalette {
    private static let ramp: [Color] = [
        Color(red: 0.90, green: 0.26, blue: 0.21), Color(red: 0.96, green: 0.55, blue: 0.09),
        Color(red: 0.23, green: 0.51, blue: 0.96), Color(red: 0.45, green: 0.50, blue: 0.58),
    ]
    static func color(_ id: String, _ priorities: [Priority]) -> Color? {
        guard let rank = priorities.firstIndex(where: { $0.id == id }) else { return .gray }
        return ramp[min(rank, ramp.count - 1)]
    }
}
