import Foundation

struct ConfigStore {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() throws -> GitFolderConfig {
        let url = try configURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .empty
        }

        let data = try Data(contentsOf: url)
        do {
            let config = try decoder.decode(GitFolderConfig.self, from: data)
            guard config.schemaVersion == 1 else {
                throw ConfigStoreError.unsupportedSchemaVersion(config.schemaVersion)
            }
            return config
        } catch {
            try backupInvalidConfig(at: url)
            throw error
        }
    }

    func save(_ config: GitFolderConfig) throws {
        let url = try configURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try encoder.encode(config)
        try data.write(to: url, options: [.atomic])
    }

    private func configURL() throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return support.appending(path: "GitFolder", directoryHint: .isDirectory).appending(path: "config.json")
    }

    private func backupInvalidConfig(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let backup = url.deletingLastPathComponent().appending(path: "config.invalid.\(Int(Date().timeIntervalSince1970)).json")
        try FileManager.default.copyItem(at: url, to: backup)
    }
}

enum ConfigStoreError: LocalizedError, Sendable {
    case unsupportedSchemaVersion(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let version):
            "Unsupported config schema version: \(version)"
        }
    }
}
