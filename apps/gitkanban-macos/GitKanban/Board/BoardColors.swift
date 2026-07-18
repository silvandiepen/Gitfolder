import GitKit
import SwiftUI

/// Shared lane/priority colours. Index-based for now (lane order = colour); this
/// is the placeholder until colours live in the board config (named palette).
enum LaneColor {
    static let palette: [Color] = [
        Color(red: 0.55, green: 0.36, blue: 0.96), // purple
        Color(red: 0.23, green: 0.51, blue: 0.96), // blue
        Color(red: 0.96, green: 0.62, blue: 0.09), // orange
        Color(red: 0.91, green: 0.70, blue: 0.05), // yellow
        Color(red: 0.13, green: 0.77, blue: 0.37), // green
        Color(red: 0.09, green: 0.64, blue: 0.72), // teal
        Color(red: 0.93, green: 0.28, blue: 0.60), // pink
    ]

    static func at(_ index: Int) -> Color {
        palette[((index % palette.count) + palette.count) % palette.count]
    }

    /// The colour of the lane holding `status` in `lanes` (by index), or gray.
    static func forStatus(_ status: String, in lanes: [Lane]) -> Color {
        guard let index = lanes.firstIndex(where: { $0.status == status }) else { return .gray }
        return at(index)
    }
}

/// Priority colours, ranked hot→cool by the priority's position in the config
/// (first priority = most urgent = red). Unknown priorities fall back to gray.
enum PriorityColor {
    private static let ramp: [Color] = [
        Color(red: 0.90, green: 0.26, blue: 0.21), // rank 0 — red
        Color(red: 0.96, green: 0.55, blue: 0.09), // rank 1 — orange
        Color(red: 0.23, green: 0.51, blue: 0.96), // rank 2 — blue
        Color(red: 0.45, green: 0.50, blue: 0.58), // rank 3+ — slate
    ]

    static func color(for id: String?, in priorities: [Priority]) -> Color? {
        guard let id, !id.isEmpty else { return nil }
        guard let rank = priorities.firstIndex(where: { $0.id == id }) else { return .gray }
        return ramp[min(rank, ramp.count - 1)]
    }
}

/// SF Symbol for a task type (feature/bug/…); falls back to a tag.
enum TypeIcon {
    static func name(_ type: String) -> String {
        switch type.lowercased() {
        case "feature": return "star"
        case "bug", "defect": return "ant"
        case "enhancement", "improvement": return "sparkles"
        case "chore": return "wrench.and.screwdriver"
        case "task": return "checkmark.circle"
        case "docs", "documentation": return "doc.text"
        case "design": return "paintbrush"
        case "refactor": return "arrow.triangle.2.circlepath"
        case "test", "testing": return "checklist"
        case "release": return "shippingbox"
        case "spike", "research": return "magnifyingglass"
        default: return "tag"
        }
    }
}
