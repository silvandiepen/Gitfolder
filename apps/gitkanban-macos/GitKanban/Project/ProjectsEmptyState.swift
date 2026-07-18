import SwiftUI

/// The "No projects yet" empty state shown in the board area when the opened
/// repository has no projects: a stylized board illustration, heading, and a
/// prominent Create Project button.
struct ProjectsEmptyState: View {
    var onCreate: () -> Void

    private let blue = LinearGradient(
        colors: [Color(red: 0.20, green: 0.52, blue: 0.98), Color(red: 0.11, green: 0.40, blue: 0.92)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    private let indigo = LinearGradient(
        colors: [Color(red: 0.42, green: 0.42, blue: 0.86), Color(red: 0.31, green: 0.30, blue: 0.72)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    private let slate = LinearGradient(
        colors: [Color(red: 0.20, green: 0.24, blue: 0.34), Color(red: 0.13, green: 0.16, blue: 0.24)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    var body: some View {
        VStack(spacing: 24) {
            illustration
            VStack(spacing: 8) {
                Text("No projects yet")
                    .font(.system(size: 30, weight: .bold))
                Text("Create your first project to get started.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Button(action: onCreate) {
                Label("Create Project", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24).padding(.vertical, 13)
                    .background(blue, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: Color(red: 0.15, green: 0.45, blue: 0.95).opacity(0.5), radius: 14, y: 5)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var illustration: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [Color(red: 0.22, green: 0.42, blue: 0.9).opacity(0.30), .clear],
                    center: .center, startRadius: 6, endRadius: 175))
                .frame(width: 350, height: 350)
                .blur(radius: 6)

            boardPanel.frame(width: 178, height: 150)

            badge(system: "arrow.triangle.branch", fill: blue, glow: Color(red: 0.20, green: 0.52, blue: 0.98))
                .offset(x: -106, y: -8)
            badge(system: "checkmark", fill: indigo, glow: Color(red: 0.42, green: 0.42, blue: 0.86))
                .offset(x: 106, y: 20)
            badge(system: "chevron.left.forwardslash.chevron.right", fill: slate, glow: .black)
                .offset(x: 0, y: 82)
        }
        .frame(height: 270)
    }

    private var boardPanel: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(LinearGradient(
                colors: [Color.white.opacity(0.10), Color.white.opacity(0.03)],
                startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
            .overlay(
                VStack(spacing: 12) {
                    row(); row(); row()
                }.padding(18)
            )
            .shadow(color: .black.opacity(0.4), radius: 18, y: 8)
    }

    private func row() -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 5).fill(.white.opacity(0.20)).frame(width: 26, height: 22)
            RoundedRectangle(cornerRadius: 5).fill(.white.opacity(0.12)).frame(height: 13)
        }
    }

    private func badge(system: String, fill: LinearGradient, glow: Color) -> some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(fill)
            .frame(width: 60, height: 60)
            .overlay(Image(systemName: system).font(.title2).fontWeight(.semibold).foregroundStyle(.white))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(.white.opacity(0.15), lineWidth: 1))
            .shadow(color: glow.opacity(0.5), radius: 14, y: 5)
    }
}

/// The blue gradient "New Project" button used at the top of the sidebar.
struct NewProjectButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("New Project", systemImage: "plus")
                .font(.callout).fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.20, green: 0.52, blue: 0.98), Color(red: 0.11, green: 0.40, blue: 0.92)],
                        startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: Color(red: 0.15, green: 0.45, blue: 0.95).opacity(0.45), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }
}
