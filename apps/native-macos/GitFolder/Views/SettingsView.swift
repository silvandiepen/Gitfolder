import AppKit
import GitKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @State private var selectedSection: SettingsSection = .sync
    @State private var isSidebarExpanded = true
    @State private var githubToken = ""
    @State private var gitHubAuthMode: GitHubAuthSetupMode = .connect
    @State private var gitHubAuthorization: GitHubDeviceAuthorization?
    @State private var isConnectingGitHub = false
    @State private var gitHubConnectionMessage: String?

    var body: some View {
        HStack(spacing: 0) {
            settingsSidebar
                .frame(width: isSidebarExpanded ? 220 : 76)
            Divider()

            VStack(spacing: 0) {
                HStack {
                    Button {
                        withAnimation(.snappy(duration: 0.18)) {
                            isSidebarExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isSidebarExpanded ? "sidebar.left" : "sidebar.right")
                    }
                    .buttonStyle(.borderless)
                    .help(isSidebarExpanded ? "Collapse sidebar" : "Expand sidebar")

                    Spacer()
                    Text("GitFolder")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Color.clear.frame(width: 24, height: 24)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 8)

                settingsPane
            }
        }
        .background(.regularMaterial)
        .frame(
            minWidth: 860,
            minHeight: SettingsWindowMetrics.preferredContentHeight,
            maxHeight: SettingsWindowMetrics.maximumContentHeight
        )
        .onAppear {
            appModel.loadIfNeeded()
            if appModel.focusedFolderID != nil {
                selectedSection = .folders
            }
        }
        .onChange(of: appModel.focusedFolderID) { _, focusedFolderID in
            if focusedFolderID != nil {
                selectedSection = .folders
            }
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

    private var settingsSidebar: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(spacing: 10) {
                AppLogoView(size: 44)
                if isSidebarExpanded {
                    Text("GitFolder")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 52)

            VStack(spacing: 6) {
                ForEach(SettingsSection.allCases) { section in
                    Button {
                        selectedSection = section
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: section.systemImage)
                                .font(.title3)
                                .frame(width: 22)
                            if isSidebarExpanded {
                                Text(section.title)
                                    .font(.headline)
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .foregroundStyle(selectedSection == section ? Color.accentColor : Color.primary)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selectedSection == section ? Color.accentColor.opacity(0.14) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .help(section.title)
                }
            }

            Spacer()

            if isSidebarExpanded {
                Text("v1.0.0")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 18)
                    .padding(.leading, 12)
            }
        }
        .padding(.horizontal, isSidebarExpanded ? 16 : 10)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var settingsPane: some View {
        switch selectedSection {
        case .sync:
            syncSettings
        case .github:
            githubSettings
        case .identity:
            identitySettings
        case .folders:
            folderSettings
        }
    }

    private var syncSettings: some View {
        SettingsPane(title: "Sync", subtitle: "Control automatic syncing and run manual updates.") {
            SettingsCard {
                SettingsFieldRow(systemImage: "pause.fill", title: "Pause all syncing") {
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
                    .labelsHidden()
                }

                SettingsDivider()

                SettingsFieldRow(systemImage: "power", title: "Open at login") {
                    Toggle(
                        "Open at login",
                        isOn: Binding(
                            get: { appModel.config.app.launchAtLogin },
                            set: { newValue in
                                appModel.setLaunchAtLogin(newValue)
                            }
                        )
                    )
                    .labelsHidden()
                }

                SettingsDivider()

                SettingsFieldRow(systemImage: "clock", title: "Default interval") {
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
                    .labelsHidden()
                    .frame(width: 160)
                }

                SettingsDivider()

                SettingsFieldRow(systemImage: "arrow.triangle.2.circlepath", title: "Manual sync") {
                    Button(appModel.isSyncing ? "Syncing..." : "Sync All Now", systemImage: "arrow.triangle.2.circlepath") {
                        appModel.syncNow()
                    }
                    .disabled(appModel.isSyncing || appModel.config.folders.isEmpty)
                }
            }
        }
    }

    private var githubSettings: some View {
        SettingsPane(title: "GitHub", subtitle: "Connect GitFolder to GitHub and manage HTTPS token access.") {
            SettingsCard {
                SettingsFieldRow(systemImage: appModel.hasGitHubToken ? "key.fill" : "key", title: "Connection") {
                    HStack(spacing: 12) {
                        Text(gitHubConnectionStatus)
                            .foregroundStyle(appModel.hasGitHubToken ? Color.secondary : Color.orange)
                        if appModel.hasGitHubToken {
                            Button("Disconnect", role: .destructive) {
                                githubToken = ""
                                appModel.clearGitHubToken()
                                gitHubAuthorization = nil
                                gitHubConnectionMessage = nil
                            }
                        }
                    }
                }

                if appModel.hasGitHubToken {
                    SettingsDivider()

                    SettingsFieldRow(systemImage: "person.crop.circle.badge.checkmark", title: "GitHub account") {
                        HStack(spacing: 12) {
                            Text(appModel.gitHubLogin.map { "@\($0)" } ?? "Connected")
                                .foregroundStyle(.secondary)

                            Button(isConnectingGitHub ? "Waiting..." : "Reconnect", systemImage: "arrow.triangle.2.circlepath") {
                                connectGitHub()
                            }
                            .disabled(isConnectingGitHub)
                        }
                    }
                } else {
                    SettingsDivider()

                    SettingsFieldRow(systemImage: "switch.2", title: "Connection method") {
                        Picker("Connection method", selection: $gitHubAuthMode) {
                            Text("Connect").tag(GitHubAuthSetupMode.connect)
                            Text("PAT").tag(GitHubAuthSetupMode.pat)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 260)
                    }

                    SettingsDivider()

                    switch gitHubAuthMode {
                    case .connect:
                        SettingsFieldRow(systemImage: "person.crop.circle.badge.checkmark", title: "GitHub account") {
                            VStack(alignment: .trailing, spacing: 10) {
                                Button(isConnectingGitHub ? "Waiting for GitHub..." : "Connect GitHub", systemImage: "link") {
                                    connectGitHub()
                                }
                                .disabled(isConnectingGitHub)

                                if let gitHubAuthorization {
                                    GitHubDeviceCodeRow(authorization: gitHubAuthorization)
                                        .frame(maxWidth: 420)
                                }
                            }
                        }
                    case .pat:
                        SettingsFieldRow(systemImage: "lock.rectangle", title: "Fine-grained token") {
                            HStack(spacing: 10) {
                                SecureField("GitHub token", text: $githubToken)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 320)

                                Button("Save Token") {
                                    appModel.saveGitHubToken(githubToken)
                                    githubToken = ""
                                }
                                .disabled(githubToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                    }
                }

                if let gitHubAuthorization, appModel.hasGitHubToken {
                    SettingsDivider()
                    GitHubDeviceCodeRow(authorization: gitHubAuthorization)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                }

                if let gitHubConnectionMessage {
                    SettingsDivider()
                    Text(gitHubConnectionMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 2)
                }
            }

            Text("GitFolder stores GitHub access in macOS Keychain and uses HTTPS repository URLs by default.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)
        }
    }

    private var gitHubConnectionStatus: String {
        guard appModel.hasGitHubToken else { return "No token saved" }
        if let login = appModel.gitHubLogin {
            return "Connected as @\(login)"
        }
        return "Connected with saved token"
    }

    private var identitySettings: some View {
        SettingsPane(title: "Git Identity", subtitle: "Set the Git author used for snapshot commits.") {
            SettingsCard {
                SettingsFieldRow(systemImage: "person", title: "Author name") {
                    TextField(
                        "Name",
                        text: Binding(
                            get: { appModel.config.app.gitAuthorName ?? "" },
                            set: { newValue in
                                appModel.config.app.gitAuthorName = newValue.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                                appModel.save(message: "Git author updated")
                            }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)
                }

                SettingsDivider()

                SettingsFieldRow(systemImage: "envelope", title: "Author email") {
                    TextField(
                        "Email",
                        text: Binding(
                            get: { appModel.config.app.gitAuthorEmail ?? "" },
                            set: { newValue in
                                appModel.config.app.gitAuthorEmail = newValue.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                                appModel.save(message: "Git email updated")
                            }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)
                }

            }
        }
    }

    private var folderSettings: some View {
        SettingsPane(title: "Folders", subtitle: "Manage the local folders you sync with GitHub.") {
            if appModel.config.folders.isEmpty {
                SettingsCard {
                    ContentUnavailableView(
                        "No folders yet",
                        systemImage: "folder.badge.plus",
                        description: Text("Add a folder and connect it to a GitHub HTTPS repository URL.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                }
            } else {
                ForEach(appModel.config.folders) { folder in
                    FolderSettingsRow(folder: folder)
                }
            }

            Button {
                appModel.showAddFolderSheet()
            } label: {
                Label("Add Folder...", systemImage: "plus")
                    .frame(minWidth: 150)
            }
            .controlSize(.large)
        }
    }

    private func connectGitHub() {
        isConnectingGitHub = true
        gitHubAuthorization = nil
        gitHubConnectionMessage = "Requesting a GitHub sign-in code…"

        Task {
            do {
                let authorization = try await appModel.requestGitHubConnectionCode()
                await MainActor.run {
                    gitHubAuthorization = authorization
                    gitHubConnectionMessage = "Enter this code on GitHub, then approve GitFolder."
                    NSWorkspace.shared.open(authorization.verificationURI)
                }
                let connected = await appModel.finishGitHubConnection(authorization)
                await MainActor.run {
                    isConnectingGitHub = false
                    if connected {
                        gitHubAuthorization = nil
                        gitHubConnectionMessage = "GitHub connected."
                    } else {
                        gitHubConnectionMessage = appModel.lastMessage
                    }
                }
            } catch {
                await MainActor.run {
                    isConnectingGitHub = false
                    appModel.lastMessage = "GitHub connection failed: \(error.localizedDescription)"
                    gitHubConnectionMessage = appModel.lastMessage
                }
            }
        }
    }
}

private struct FolderSettingsRow: View {
    @Environment(AppModel.self) private var appModel
    @State private var draft: SyncedFolder
    @State private var remoteBranches: [String] = []
    @State private var isLoadingBranches = false

    init(folder: SyncedFolder) {
        _draft = State(initialValue: folder)
    }

    var body: some View {
        SettingsCard {
            HStack(alignment: .center, spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.secondary.opacity(0.14))
                        .frame(width: 62, height: 62)

                    Image(systemName: "folder")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: statusSymbol)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(statusColor(for: currentFolder.lastStatus))
                        .background(Circle().fill(.background))
                        .offset(x: 6, y: 6)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(draft.name)
                            .font(.title3.weight(.semibold))

                        if !draft.enabled {
                            Text("Paused")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(.secondary.opacity(0.14))
                                .clipShape(Capsule())
                        }
                    }

                    Text(draft.localPath)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()
                statusBadge
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 16)

            VStack(spacing: 0) {
                FolderFieldRow(systemImage: "link", title: "Repository URL") {
                    HStack(spacing: 10) {
                        TextField("https://github.com/owner/repo.git", text: $draft.repoUrl)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(width: 420)

                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(draft.repoUrl, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("Copy repository URL")
                        .disabled(draft.repoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                SettingsDivider()

                FolderFieldRow(systemImage: "point.3.connected.trianglepath.dotted", title: "Branch") {
                    HStack(spacing: 10) {
                        Picker("Branch", selection: $draft.branch) {
                            ForEach(branchPickerOptions, id: \.self) { branch in
                                Text(branch).tag(branch)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)

                        Button {
                            loadBranches()
                        } label: {
                            Image(systemName: isLoadingBranches ? "hourglass" : "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .help("Load branches from GitHub")
                        .disabled(isLoadingBranches || draft.repoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !appModel.hasGitHubToken)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }

                SettingsDivider()

                FolderFieldRow(systemImage: "clock", title: "Sync Interval") {
                    Picker("Interval", selection: $draft.syncIntervalMinutes) {
                        Text("5 min").tag(5)
                        Text("15 min").tag(15)
                        Text("30 min").tag(30)
                        Text("60 min").tag(60)
                    }
                    .labelsHidden()
                    .frame(width: 130)
                    .fixedSize(horizontal: true, vertical: false)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 18)

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
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }

            HStack {
                Button(draft.enabled ? "Pause" : "Resume", systemImage: draft.enabled ? "pause.fill" : "play.fill") {
                    appModel.updateFolder(tokenAuthDraft())
                    appModel.toggleFolder(id: draft.id)
                    if let updated = appModel.config.folders.first(where: { $0.id == draft.id }) {
                        draft = updated
                    }
                }
                .frame(minWidth: 120)

                Button("Save", systemImage: "square.and.arrow.down") {
                    appModel.updateFolder(tokenAuthDraft())
                }
                .frame(minWidth: 120)

                Button("Sync Now", systemImage: "arrow.triangle.2.circlepath") {
                    appModel.updateFolder(tokenAuthDraft())
                    appModel.syncNow(folderID: draft.id)
                }
                .buttonStyle(.borderedProminent)
                .frame(minWidth: 140)
                .disabled(appModel.isSyncing || draft.repoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()

                Button("Remove", systemImage: "trash", role: .destructive) {
                    appModel.removeFolder(id: draft.id)
                }
                .frame(minWidth: 120)
            }
            .padding(18)
            .padding(.top, 2)
        }
        .overlay(alignment: .top) {
            if isFocused {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.55), lineWidth: 1)
            }
        }
        .contextMenu {
            Button("Sync Now") {
                appModel.updateFolder(tokenAuthDraft())
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
        .onChange(of: draft.repoUrl) { _, _ in
            remoteBranches = []
        }
        .onAppear {
            if remoteBranches.isEmpty, !draft.repoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, appModel.hasGitHubToken {
                loadBranches()
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

    private var branchPickerOptions: [String] {
        let current = draft.branch.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "main"
        return Array(Set(remoteBranches + [current])).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private func tokenAuthDraft() -> SyncedFolder {
        var copy = draft
        copy.authMode = AuthMode.githubToken.rawValue
        return copy
    }

    private func loadBranches() {
        isLoadingBranches = true
        let repoUrl = draft.repoUrl
        Task {
            let branches = await appModel.loadRemoteBranches(repoUrl: repoUrl)
            await MainActor.run {
                remoteBranches = branches
                if !branches.isEmpty, !branches.contains(draft.branch) {
                    draft.branch = branches.contains("main") ? "main" : branches[0]
                }
                isLoadingBranches = false
            }
        }
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
    @State private var isTesting = false
    @State private var gitHubAuthorization: GitHubDeviceAuthorization?
    @State private var isConnectingGitHub = false
    @State private var gitHubConnectionMessage: String?
    @State private var remoteBranches: [String] = []
    @State private var isLoadingBranches = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Add Folder")
                    .font(.title.bold())
                Text("Choose a local folder and connect it to a GitHub repository.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            SettingsCard {
                SettingsFieldRow(systemImage: "folder", title: "Local folder") {
                    HStack(spacing: 12) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(selectedURL?.lastPathComponent ?? "No folder selected")
                                .font(.headline)
                            if let selectedURL {
                                Text(selectedURL.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }

                        Button("Choose...", systemImage: "folder.badge.plus") {
                            selectedURL = FolderAccessService().pickFolder()
                        }
                    }
                }

                SettingsDivider()

                SettingsFieldRow(systemImage: "link", title: "Repository URL") {
                    TextField("https://github.com/owner/repo.git", text: $repoUrl)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 360)
                        .onChange(of: repoUrl) { _, _ in
                            remoteBranches = []
                        }
                }

                if !appModel.hasGitHubToken {
                    SettingsDivider()

                    SettingsFieldRow(systemImage: "key", title: "GitHub") {
                        VStack(alignment: .trailing, spacing: 10) {
                            Button(isConnectingGitHub ? "Waiting for GitHub..." : "Connect GitHub", systemImage: "link") {
                                connectGitHub()
                            }
                            .disabled(isConnectingGitHub)

                            if let gitHubAuthorization {
                                GitHubDeviceCodeRow(authorization: gitHubAuthorization)
                                    .frame(width: 360)
                            }

                            if let gitHubConnectionMessage {
                                Text(gitHubConnectionMessage)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                SettingsDivider()

                SettingsFieldRow(systemImage: "point.3.connected.trianglepath.dotted", title: "Branch") {
                    HStack(spacing: 10) {
                        Picker("Branch", selection: $branch) {
                            ForEach(branchPickerOptions, id: \.self) { branch in
                                Text(branch).tag(branch)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)

                        Button {
                            loadBranches()
                        } label: {
                            Image(systemName: isLoadingBranches ? "hourglass" : "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .help("Load branches from GitHub")
                        .disabled(isLoadingBranches || repoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !appModel.hasGitHubToken)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }

                SettingsDivider()

                SettingsFieldRow(systemImage: "clock", title: "Sync Interval") {
                    Picker("Interval", selection: $interval) {
                        Text("5 minutes").tag(5)
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                        Text("60 minutes").tag(60)
                    }
                    .labelsHidden()
                    .frame(width: 150)
                    .fixedSize(horizontal: true, vertical: false)
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
                Button(isTesting ? "Testing…" : "Test, Add and Sync") {
                    addAndSync()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isTesting || selectedURL == nil || repoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !appModel.hasGitHubToken)
            }
        }
        .padding()
        .frame(width: 680)
    }

    private func addAndSync() {
        guard let selectedURL else { return }
        isTesting = true
        Task {
            let hasAccess = await appModel.testGitHubAccess(repoUrl: repoUrl, authMode: .githubToken)
            await MainActor.run {
                isTesting = false
                guard hasAccess else {
                    errorMessage = appModel.lastMessage
                    return
                }
                do {
                    let id = try appModel.addFolder(localURL: selectedURL, repoUrl: repoUrl, authMode: .githubToken, branch: branch, syncIntervalMinutes: interval)
                    isPresented = false
                    appModel.syncNow(folderID: id)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func connectGitHub() {
        isConnectingGitHub = true
        gitHubAuthorization = nil
        gitHubConnectionMessage = "Requesting a GitHub sign-in code…"

        Task {
            do {
                let authorization = try await appModel.requestGitHubConnectionCode()
                await MainActor.run {
                    gitHubAuthorization = authorization
                    gitHubConnectionMessage = "Enter this code on GitHub, then approve GitFolder."
                    NSWorkspace.shared.open(authorization.verificationURI)
                }
                let connected = await appModel.finishGitHubConnection(authorization)
                await MainActor.run {
                    isConnectingGitHub = false
                    if connected {
                        gitHubAuthorization = nil
                        gitHubConnectionMessage = "GitHub connected."
                    } else {
                        gitHubConnectionMessage = appModel.lastMessage
                    }
                }
            } catch {
                await MainActor.run {
                    isConnectingGitHub = false
                    appModel.lastMessage = "GitHub connection failed: \(error.localizedDescription)"
                    gitHubConnectionMessage = appModel.lastMessage
                }
            }
        }
    }

    private var branchPickerOptions: [String] {
        let current = branch.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "main"
        return Array(Set(remoteBranches + [current])).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private func loadBranches() {
        isLoadingBranches = true
        let repoUrl = repoUrl
        Task {
            let branches = await appModel.loadRemoteBranches(repoUrl: repoUrl)
            await MainActor.run {
                remoteBranches = branches
                if !branches.isEmpty, !branches.contains(branch) {
                    branch = branches.contains("main") ? "main" : branches[0]
                }
                isLoadingBranches = false
            }
        }
    }
}

private enum GitHubAuthSetupMode: Hashable {
    case connect
    case pat
}

private struct SettingsPane<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.largeTitle.weight(.bold))
                    Text(subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                content
            }
            .frame(maxWidth: 860, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct SettingsFieldRow<Content: View>: View {
    let systemImage: String
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 26)

            Text(title)
                .font(.headline)

            Spacer(minLength: 24)

            content
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

private struct FolderFieldRow<Content: View>: View {
    let systemImage: String
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 26)

            Text(title)
                .font(.headline)
                .frame(width: 160, alignment: .leading)

            Spacer(minLength: 20)

            content
                .frame(minWidth: 0, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 60)
    }
}

private struct AppLogoView: View {
    let size: CGFloat

    var body: some View {
        Image("GitFolderLogo")
            .resizable()
            .renderingMode(.original)
            .interpolation(.high)
            .frame(width: size, height: size)
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
    case sync
    case github
    case identity
    case folders

    var id: Self { self }

    var title: String {
        switch self {
        case .sync: return "Sync"
        case .github: return "GitHub"
        case .identity: return "Git Identity"
        case .folders: return "Folders"
        }
    }

    var systemImage: String {
        switch self {
        case .sync: return "arrow.triangle.2.circlepath"
        case .github: return "key"
        case .identity: return "person.text.rectangle"
        case .folders: return "folder"
        }
    }
}

private enum SettingsWindowMetrics {
    static var preferredContentHeight: CGFloat {
        min(840, maximumContentHeight)
    }

    static var maximumContentHeight: CGFloat {
        guard let screen = NSScreen.main else { return 760 }
        return max(520, screen.visibleFrame.height - 72)
    }
}

private struct GitHubDeviceCodeRow: View {
    let authorization: GitHubDeviceAuthorization
    @State private var copiedCode = false

    var body: some View {
        HStack(spacing: 8) {
            Text(authorization.userCode)
                .font(.system(.title3, design: .monospaced).weight(.semibold))
                .textSelection(.enabled)

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(authorization.userCode, forType: .string)
                copiedCode = true
            } label: {
                Image(systemName: copiedCode ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help(copiedCode ? "Copied" : "Copy code")

            Spacer()

            Button("Open GitHub") {
                NSWorkspace.shared.open(authorization.verificationURI)
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
