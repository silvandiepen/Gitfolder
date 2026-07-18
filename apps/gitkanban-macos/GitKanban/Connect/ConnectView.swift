import GitKit
import SwiftUI

/// The first screen: connect a GitHub account via the device flow.
struct ConnectView: View {
    @Environment(AppModel.self) private var model
    @State private var copied = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("GitKanban")
                .font(.largeTitle).fontWeight(.semibold)
            Text("Connect your GitHub account to pick a repository and manage its board.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            if let auth = model.deviceAuth {
                deviceCode(auth)
            } else {
                Button {
                    Task { await model.connect() }
                } label: {
                    Text("Connect GitHub")
                        .frame(minWidth: 160)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(model.isAuthorizing)
            }

            if let error = model.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func deviceCode(_ auth: GitHubDeviceAuthorization) -> some View {
        VStack(spacing: 14) {
            Text("Enter this code on GitHub")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                copyCode(auth.userCode)
            } label: {
                HStack(spacing: 10) {
                    Text(auth.userCode)
                        .font(.system(.largeTitle, design: .monospaced))
                        .fontWeight(.bold)
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.title3)
                        .foregroundStyle(copied ? .green : .secondary)
                }
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                .contentShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .help("Click to copy")
            Text(copied ? "Copied!" : "Click the code to copy")
                .font(.caption)
                .foregroundStyle(copied ? .green : .secondary)

            Link(auth.verificationURI.absoluteString, destination: auth.verificationURI)
                .font(.callout)

            Button("Open GitHub") {
                NSWorkspace.shared.open(auth.verificationURI)
            }
            .controlSize(.large)

            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Waiting for authorization…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func copyCode(_ code: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(code, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }
}
