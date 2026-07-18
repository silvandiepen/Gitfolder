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
}
