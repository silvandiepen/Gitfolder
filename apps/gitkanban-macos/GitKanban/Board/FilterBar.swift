import GitKit
import SwiftUI

/// A filter/search strip above the board: filter cards by assignee, priority, or
/// type, open the search sheet, and clear active filters.
struct FilterBar: View {
    @Environment(AppModel.self) private var model

    private var config: EffectiveConfig? { model.board?.config }

    /// All cards on the current board (lanes + backlog), for deriving filter options.
    private var allCards: [Card] {
        (model.board?.columns.flatMap(\.cards) ?? []) + (model.board?.uncategorised ?? [])
    }

    private var assignees: [String] {
        let fromConfig = config?.users.map(\.id) ?? []
        let fromCards = allCards.compactMap(\.fields.assignee)
        return Array(Set(fromConfig + fromCards)).sorted()
    }

    private var priorities: [Priority] { config?.priorities ?? [] }

    private var types: [String] {
        let fromConfig = config?.types ?? []
        let fromCards = allCards.compactMap(\.fields.type)
        return Array(Set(fromConfig + fromCards)).sorted()
    }

    private func userName(_ id: String) -> String {
        config?.users.first { $0.id == id }?.name ?? id
    }

    var body: some View {
        @Bindable var model = model
        return HStack(spacing: 8) {
            Button {
                model.isShowingSearch = true
            } label: {
                Label("Search", systemImage: "magnifyingglass")
                    .font(.callout)
            }
            .buttonStyle(.bordered)
            .keyboardShortcut("f", modifiers: .command)
            .help("Search tasks (⌘F)")

            Divider().frame(height: 16)

            filterMenu(
                title: "Assignee",
                systemImage: "person.crop.circle",
                selection: model.filterAssignee,
                selectedLabel: model.filterAssignee.map(userName)
            ) {
                Button("Anyone") { model.filterAssignee = nil }
                Divider()
                ForEach(assignees, id: \.self) { id in
                    Button {
                        model.filterAssignee = id
                    } label: {
                        Label(userName(id), systemImage: model.filterAssignee == id ? "checkmark" : "")
                    }
                }
            }

            if !priorities.isEmpty {
                filterMenu(
                    title: "Priority",
                    systemImage: "flag",
                    selection: model.filterPriority,
                    selectedLabel: model.filterPriority
                ) {
                    Button("Any priority") { model.filterPriority = nil }
                    Divider()
                    ForEach(priorities, id: \.id) { priority in
                        Button {
                            model.filterPriority = priority.id
                        } label: {
                            Label(priority.name ?? priority.id, systemImage: "flag.fill")
                                .foregroundStyle(PriorityColor.color(for: priority.id, in: priorities) ?? .gray)
                        }
                    }
                }
            }

            if !types.isEmpty {
                filterMenu(
                    title: "Type",
                    systemImage: "tag",
                    selection: model.filterType,
                    selectedLabel: model.filterType
                ) {
                    Button("Any type") { model.filterType = nil }
                    Divider()
                    ForEach(types, id: \.self) { type in
                        Button {
                            model.filterType = type
                        } label: {
                            Label(type.capitalized, systemImage: TypeIcon.name(type))
                        }
                    }
                }
            }

            if model.hasActiveFilters {
                Button {
                    model.clearFilters()
                } label: {
                    Label("Clear", systemImage: "xmark.circle.fill")
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Clear all filters")
            }

            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    @ViewBuilder
    private func filterMenu<Content: View>(
        title: String,
        systemImage: String,
        selection: String?,
        selectedLabel: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu {
            content()
        } label: {
            let active = selection != nil
            Label(active ? (selectedLabel ?? title) : title, systemImage: systemImage)
                .font(.callout)
                .foregroundStyle(active ? Color.accentColor : Color.primary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(
            (selection != nil ? Color.accentColor.opacity(0.12) : Color.clear),
            in: RoundedRectangle(cornerRadius: 7)
        )
    }
}
