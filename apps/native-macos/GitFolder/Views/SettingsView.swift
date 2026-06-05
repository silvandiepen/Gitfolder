import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Form {
            Section {
                Toggle(
                    "Pause all syncing",
                    isOn: Binding(
                        get: { appModel.config.app.pauseAllSyncing },
                        set: { newValue in
                            appModel.config.app.pauseAllSyncing = newValue
                            appModel.save(message: newValue ? "Syncing paused" : "Syncing resumed")
                        }
                    )
                )

                Picker(
                    "Default interval",
                    selection: Binding(
                        get: { appModel.config.app.defaultSyncIntervalMinutes },
                        set: { newValue in
                            appModel.config.app.defaultSyncIntervalMinutes = newValue
                            appModel.save(message: "Default interval updated")
                        }
                    )
                ) {
                    Text("5 minutes").tag(5)
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                    Text("60 minutes").tag(60)
                }

                Button(appModel.isSyncing ? "Syncing…" : "Sync All Now") {
                    appModel.syncNow()
                }
                .disabled(appModel.isSyncing || appModel.config.folders.isEmpty)
            } header: {
                Text("Sync")
            }

            Section {
                TextField(
                    "Author name",
                    text: Binding(
                        get: { appModel.config.app.gitAuthorName ?? "" },
                        set: { newValue in
                            appModel.config.app.gitAuthorName = newValue.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                            appModel.save(message: "Git author updated")
                        }
                    )
                )

                TextField(
                    "Author email",
                    text: Binding(
                        get: { appModel.config.app.gitAuthorEmail ?? "" },
                        set: { newValue in
                            appModel.config.app.gitAuthorEmail = newValue.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                            appModel.save(message: "Git email updated")
                        }
                    )
                )

                HStack {
                    Text("SSH key")
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(appModel.config.app.sshPrivateKeyPath?.lastPathComponent ?? "System default")
                            .lineLimit(1)
                            .truncationMode(.middle)
                        HStack(spacing: 8) {
                            if appModel.config.app.sshPrivateKeyPath != nil {
                                Button("Clear") {
                                    appModel.clearSSHPrivateKey()
                                }
                            }
                            Button("Choose…") {
                                appModel.chooseSSHPrivateKey()
                            }
                        }
                    }
                }

                Text("If the App Store sandbox cannot read your default SSH key, choose one manually.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Git Identity")
            }

            Section {
                if appModel.config.folders.isEmpty {
                    ContentUnavailableView(
                        "No folders yet",
                        systemImage: "folder.badge.plus",
                        description: Text("Add a folder and connect it to a GitHub SSH repository URL.")
                    )
                } else {
                    ForEach(appModel.config.folders) { folder in
                        FolderSettingsRow(folder: folder)
                    }
                }

                Button {
                    appModel.showAddFolderSheet()
                } label: {
                    Label("Add Folder…", systemImage: "folder.badge.plus")
                }
            } header: {
                Text("Folders")
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 620, minHeight: 480)
        .onAppear {
            appModel.loadIfNeeded()
        }
        .sheet(isPresented: Binding(
            get: { appModel.isShowingAddFolderSheet },
            set: { appModel.isShowingAddFolderSheet = $0 }
        )) {
            AddFolderSheet(isPresented: Binding(
                get: { appModel.isShowingAddFolderSheet },
                set: { appModel.isShowingAddFolderSheet = $0 }
            ))
                .environment(appModel)
        }
    }
}

private struct FolderSettingsRow: View {
    @Environment(AppModel.self) private var appModel
    @State private var draft: SyncedFolder

    init(folder: SyncedFolder) {
        _draft = State(initialValue: folder)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: statusSymbol)
                    .font(.title3)
                    .foregroundStyle(statusColor(for: currentFolder.lastStatus))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(draft.name)
                            .font(.headline)
                        if !draft.enabled {
                            Text("Paused")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.secondary.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    Text(draft.localPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                statusBadge
            }

            LabeledContent("Repository URL") {
                TextField("git@github.com:owner/repo.git", text: $draft.repoUrl)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)
            }

            HStack {
                LabeledContent("Branch") {
                    TextField("main", text: $draft.branch)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 160)
                }
                LabeledContent("Interval") {
                    Picker("Interval", selection: $draft.syncIntervalMinutes) {
                        Text("5m").tag(5)
                        Text("15m").tag(15)
                        Text("30m").tag(30)
                        Text("60m").tag(60)
                    }
                    .labelsHidden()
                    .frame(width: 120)
                }
            }

            if let error = latestError {
                VStack(alignment: .leading, spacing: 2) {
                    Text(error.message)
                        .font(.caption)
                        .foregroundStyle(.red)
                    if let recoverySuggestion = error.recoverySuggestion {
                        Text(recoverySuggestion)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Button(draft.enabled ? "Pause" : "Resume") {
                    appModel.updateFolder(draft)
                    appModel.toggleFolder(id: draft.id)
                    if let updated = appModel.config.folders.first(where: { $0.id == draft.id }) {
                        draft = updated
                    }
                }
                Button("Save") {
                    appModel.updateFolder(draft)
                }
                Button("Sync Now") {
                    appModel.updateFolder(draft)
                    appModel.syncNow(folderID: draft.id)
                }
                .disabled(appModel.isSyncing || draft.repoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
                Button("Remove", role: .destructive) {
                    appModel.removeFolder(id: draft.id)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isFocused ? Color.accentColor.opacity(0.10) : Color.secondary.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isFocused ? Color.accentColor.opacity(0.55) : Color.secondary.opacity(0.12), lineWidth: 1)
        )
        .contextMenu {
            Button("Sync Now") {
                appModel.updateFolder(draft)
                appModel.syncNow(folderID: draft.id)
            }
            Button("Open Folder") {
                NSWorkspace.shared.open(URL(fileURLWithPath: draft.localPath))
            }
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: draft.localPath)])
            }
            Button(draft.enabled ? "Pause Folder" : "Resume Folder") {
                appModel.toggleFolder(id: draft.id)
            }
        }
        .onChange(of: appModel.config.folders) { _, folders in
            if let updated = folders.first(where: { $0.id == draft.id }), updated.updatedAt != draft.updatedAt {
                draft = updated
            }
        }
    }

    private var statusBadge: some View {
        Text(statusText(for: currentFolder))
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor(for: currentFolder.lastStatus).opacity(0.16))
            .foregroundStyle(statusColor(for: currentFolder.lastStatus))
            .clipShape(Capsule())
    }

    private var currentFolder: SyncedFolder {
        appModel.config.folders.first(where: { $0.id == draft.id }) ?? draft
    }

    private var isFocused: Bool {
        appModel.focusedFolderID == draft.id
    }

    private var statusSymbol: String {
        switch currentFolder.lastStatus {
        case .synced: return "checkmark.circle.fill"
        case .syncing, .checking: return "arrow.triangle.2.circlepath.circle.fill"
        case .paused: return "pause.circle.fill"
        case .error, .conflict: return "exclamationmark.triangle.fill"
        case .waitingForConnection, .needsAttention: return "exclamationmark.circle.fill"
        case .idle: return currentFolder.enabled ? "folder" : "pause.circle.fill"
        }
    }

    private var latestError: UserFacingError? {
        (appModel.config.folders.first(where: { $0.id == draft.id }) ?? draft).lastError
    }

    private func statusText(for folder: SyncedFolder) -> String {
        switch folder.lastStatus {
        case .idle: return "Idle"
        case .checking: return "Checking"
        case .syncing: return "Syncing"
        case .synced: return folder.lastSuccessfulSyncAt.map { "Synced \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "Synced"
        case .paused: return "Paused"
        case .waitingForConnection: return "Waiting"
        case .needsAttention: return "Needs attention"
        case .error: return "Error"
        case .conflict: return "Conflict"
        }
    }

    private func statusColor(for status: SyncStatus) -> Color {
        switch status {
        case .synced: return .green
        case .syncing, .checking: return .blue
        case .paused, .idle: return .secondary
        case .waitingForConnection, .needsAttention: return .orange
        case .error, .conflict: return .red
        }
    }
}

private struct AddFolderSheet: View {
    @Environment(AppModel.self) private var appModel
    @Binding var isPresented: Bool

    @State private var selectedURL: URL?
    @State private var repoUrl = ""
    @State private var branch = "main"
    @State private var interval = 15
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Folder")
                .font(.title2.bold())
            Text("Choose a local folder, paste a GitHub SSH repository URL, then GitFolder will run the first snapshot sync.")
                .foregroundStyle(.secondary)

            HStack {
                VStack(alignment: .leading) {
                    Text(selectedURL?.lastPathComponent ?? "No folder selected")
                        .font(.headline)
                    if let selectedURL {
                        Text(selectedURL.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Button("Choose Folder…") {
                    selectedURL = FolderAccessService().pickFolder()
                }
            }

            TextField("git@github.com:owner/repo.git", text: $repoUrl)
                .textFieldStyle(.roundedBorder)

            HStack {
                TextField("Branch", text: $branch)
                    .textFieldStyle(.roundedBorder)
                Picker("Interval", selection: $interval) {
                    Text("5 minutes").tag(5)
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                    Text("60 minutes").tag(60)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    isPresented = false
                }
                Button("Add and Sync") {
                    addAndSync()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedURL == nil || repoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 520)
    }

    private func addAndSync() {
        guard let selectedURL else { return }
        do {
            let id = try appModel.addFolder(localURL: selectedURL, repoUrl: repoUrl, branch: branch, syncIntervalMinutes: interval)
            isPresented = false
            appModel.syncNow(folderID: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
