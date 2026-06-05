import AppKit
import Foundation

struct FolderAccessService: Sendable {
    func pickFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.prompt = "Add Folder"
        return panel.runModal() == .OK ? panel.url : nil
    }

    func pickPrivateKey() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.canCreateDirectories = false
        panel.prompt = "Choose SSH Key"
        panel.message = "Choose the private SSH key GitFolder should use for GitHub pushes."
        return panel.runModal() == .OK ? panel.url : nil
    }

    func bookmarkData(for url: URL) throws -> Data {
        try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    func resolveBookmark(_ data: Data) throws -> URL {
        var stale = false
        let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale)
        if stale {
            throw FolderAccessError.staleBookmark
        }
        return url
    }

    func withSecurityScopedAccess<T>(for folder: SyncedFolder, operation: (URL) throws -> T) throws -> T {
        let url: URL
        if let bookmarkData = folder.bookmarkData {
            url = try resolveBookmark(bookmarkData)
        } else {
            url = URL(fileURLWithPath: folder.localPath)
        }

        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return try operation(url)
    }
}

enum FolderAccessError: LocalizedError, Sendable {
    case staleBookmark

    var errorDescription: String? {
        switch self {
        case .staleBookmark:
            "Folder access needs to be refreshed."
        }
    }
}
