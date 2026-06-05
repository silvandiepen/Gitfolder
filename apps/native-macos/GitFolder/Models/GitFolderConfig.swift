import Foundation

struct GitFolderConfig: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var app: AppSettings
    var license: ProductLicense
    var folders: [SyncedFolder]

    static let empty = GitFolderConfig(
        schemaVersion: 1,
        app: .defaults,
        license: .appStoreLifetime,
        folders: []
    )
}

struct ProductLicense: Codable, Equatable, Sendable {
    var purchaseModel: String
    var priceEur: Int
    var entitlement: String
    var trial: Bool
    var subscription: Bool
    var inAppPurchases: Bool

    static let appStoreLifetime = ProductLicense(
        purchaseModel: "app_store_paid_upfront",
        priceEur: 5,
        entitlement: "lifetime",
        trial: false,
        subscription: false,
        inAppPurchases: false
    )
}

struct AppSettings: Codable, Equatable, Sendable {
    var launchAtLogin: Bool
    var pauseAllSyncing: Bool
    var defaultSyncIntervalMinutes: Int
    var defaultBranch: String
    var gitAuthorName: String?
    var gitAuthorEmail: String?
    var sshPrivateKeyPath: String?
    var sshPrivateKeyBookmarkData: Data?
    var showNotificationsFor: [String]
    var logRetentionDays: Int

    static let defaults = AppSettings(
        launchAtLogin: false,
        pauseAllSyncing: false,
        defaultSyncIntervalMinutes: 15,
        defaultBranch: "main",
        gitAuthorName: nil,
        gitAuthorEmail: nil,
        sshPrivateKeyPath: nil,
        sshPrivateKeyBookmarkData: nil,
        showNotificationsFor: [
            "sync_failed",
            "github_access_failed",
            "folder_permission_lost",
            "conflict_detected"
        ],
        logRetentionDays: 30
    )
}
