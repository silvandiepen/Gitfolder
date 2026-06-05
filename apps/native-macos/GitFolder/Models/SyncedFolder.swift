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
