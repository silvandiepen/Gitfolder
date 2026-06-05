import Foundation

struct SyncedFolder: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var localPath: String
    var bookmarkData: Data?
    var repoUrl: String
    var provider: String
    var authMode: String
    var branch: String
    var syncIntervalMinutes: Int
    var enabled: Bool
    var createdAt: Date
    var updatedAt: Date
    var lastSyncAt: Date?
    var lastSuccessfulSyncAt: Date?
    var lastCheckedAt: Date?
    var lastStatus: SyncStatus
    var lastError: UserFacingError?

    var repositoryWebURLString: String {
        Self.webURLString(fromRepositoryURL: repoUrl)
    }

    static func webURLString(fromRepositoryURL rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let normalized = stripGitSuffixAndTrailingSlashes(from: trimmed)

        if let scpLikeURL = parseScpLikeGitURL(normalized) {
            return scpLikeURL
        }

        if var components = URLComponents(string: normalized), let scheme = components.scheme?.lowercased(), let host = components.host {
            if scheme == "ssh" {
                let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                guard !path.isEmpty else { return normalized }
                return "https://\(host)/\(path)"
            }

            if scheme == "http" || scheme == "https" {
                components.scheme = "https"
                components.user = nil
                components.password = nil
                components.query = nil
                components.fragment = nil
                return stripGitSuffixAndTrailingSlashes(from: components.string ?? normalized)
            }
        }

        return normalized
    }

    private static func parseScpLikeGitURL(_ value: String) -> String? {
        guard let atIndex = value.firstIndex(of: "@"),
              let colonIndex = value[atIndex...].firstIndex(of: ":") else {
            return nil
        }

        let hostStart = value.index(after: atIndex)
        let pathStart = value.index(after: colonIndex)
        let host = String(value[hostStart..<colonIndex])
        let path = String(value[pathStart...]).trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard !host.isEmpty, !path.isEmpty else { return nil }
        return "https://\(host)/\(path)"
    }

    private static func stripGitSuffixAndTrailingSlashes(from value: String) -> String {
        var result = value
        while result.hasSuffix("/") {
            result.removeLast()
        }
        if result.hasSuffix(".git") {
            result.removeLast(4)
        }
        while result.hasSuffix("/") {
            result.removeLast()
        }
        return result
    }

    static func create(
        name: String,
        localPath: String,
        bookmarkData: Data?,
        repoUrl: String,
        branch: String = "main",
        syncIntervalMinutes: Int = 15
    ) -> SyncedFolder {
        let now = Date()
        return SyncedFolder(
            id: UUID(),
            name: name,
            localPath: localPath,
            bookmarkData: bookmarkData,
            repoUrl: repoUrl,
            provider: "github",
            authMode: "ssh",
            branch: branch,
            syncIntervalMinutes: syncIntervalMinutes,
            enabled: true,
            createdAt: now,
            updatedAt: now,
            lastSyncAt: nil,
            lastSuccessfulSyncAt: nil,
            lastCheckedAt: nil,
            lastStatus: .idle,
            lastError: nil
        )
    }
}

enum SyncStatus: String, Codable, Equatable, Sendable {
    case idle
    case checking
    case syncing
    case synced
    case paused
    case waitingForConnection = "waiting_for_connection"
    case needsAttention = "needs_attention"
    case error
    case conflict
}

struct UserFacingError: Codable, Equatable, Sendable {
    var code: String
    var title: String
    var message: String
    var recoverySuggestion: String?
    var technicalDetailsLogId: String?
}
