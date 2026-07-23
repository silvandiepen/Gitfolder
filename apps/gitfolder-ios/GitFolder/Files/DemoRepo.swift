import Foundation
import GitPontCore
import UIKit

/// The file operations FileBrowser/Editor need from a repository — implemented by
/// `RepoFileClient` (real, over a provider API) and `DemoRepoClient` (in-memory).
protocol RepoFiles {
    func list(_ directory: String) async throws -> [RepoEntry]
    func readText(_ path: String) async throws -> String
    func readData(_ path: String) async throws -> Data
    func write(path: String, text: String, message: String) async throws
    func writeData(path: String, data: Data, message: String) async throws
    func delete(path: String, message: String) async throws
}

extension RepoFileClient: RepoFiles {}

/// An offline, in-memory "repository" so the app can be explored without connecting
/// a provider: App Review and first-run users tap "Preview a demo" and get a browsable,
/// editable file tree. Edits live for the session only.
@MainActor
final class DemoRepoStore {
    static let shared = DemoRepoStore()

    /// repo fullName → (path → file contents)
    private var repos: [String: [String: Data]] = [:]

    /// The repositories shown on the demo home screen.
    static let refs: [RepoRef] = [
        RepoRef(namespace: "demo", name: "travel-journal", branch: "main", isPrivate: false),
        RepoRef(namespace: "demo", name: "recipes", branch: "main", isPrivate: true),
        RepoRef(namespace: "demo", name: "website", branch: "main", isPrivate: false),
    ]

    private init() {
        func text(_ s: String) -> Data { Data(s.utf8) }

        repos["demo/travel-journal"] = [
            "README.md": text("# Travel Journal\n\nNotes and photos from trips, one folder per year.\n"),
            "2026/kyoto.md": text("# Kyoto, March 2026\n\nCherry blossoms along the Kamo river, tea in Gion, and the quiet of Fushimi Inari at 7am — before the crowds.\n\n- Day 1: Arrival, Nishiki market\n- Day 2: Fushimi Inari, Tofuku-ji\n- Day 3: Arashiyama bamboo grove\n"),
            "2026/lisbon.md": text("# Lisbon, June 2026\n\nAzulejos, pasteis de nata, and the light on the Tejo. Tram 28 is worth it exactly once.\n"),
            "2025/oslo.md": text("# Oslo, December 2025\n\nSnow over the opera house roof. The fjord ferries still run in winter — bring gloves.\n"),
            "photos/kyoto.png": DemoRepoStore.demoImage(title: "Kyoto", tint: UIColor(red: 0.85, green: 0.45, blue: 0.5, alpha: 1)),
            "photos/lisbon.png": DemoRepoStore.demoImage(title: "Lisbon", tint: UIColor(red: 0.3, green: 0.6, blue: 0.85, alpha: 1)),
        ]

        repos["demo/recipes"] = [
            "README.md": text("# Recipes\n\nFamily recipes, versioned — because grandma's ratios should never be lost.\n"),
            "breakfast/pancakes.md": text("# Pancakes\n\n- 200g flour\n- 2 eggs\n- 300ml milk\n- pinch of salt\n\nRest the batter 20 minutes. Butter, not oil.\n"),
            "dinner/ramen.md": text("# Weeknight Ramen\n\nShortcut shoyu ramen: good stock, soft egg, scallions. 25 minutes.\n"),
            "dinner/lasagne.md": text("# Lasagne\n\nSunday version — slow ragu, fresh sheets, way too much parmesan.\n"),
        ]

        repos["demo/website"] = [
            "README.md": text("# Personal Website\n\nA tiny static site, edited from anywhere with GitFolder.\n"),
            "index.html": text("<!doctype html>\n<html>\n  <head>\n    <title>Hi, I'm Demo</title>\n    <link rel=\"stylesheet\" href=\"css/styles.css\" />\n  </head>\n  <body>\n    <h1>Hello!</h1>\n    <p>This site is edited straight from my phone.</p>\n  </body>\n</html>\n"),
            "css/styles.css": text("body {\n  font-family: -apple-system, sans-serif;\n  margin: 3rem auto;\n  max-width: 40rem;\n  line-height: 1.6;\n}\n"),
            "docs/ideas.md": text("# Ideas\n\n- Photo page for trips\n- Dark mode\n- RSS feed for notes\n"),
            "assets/logo.png": DemoRepoStore.demoImage(title: "logo", tint: UIColor(red: 0.73, green: 0.84, blue: 0.34, alpha: 1)),
        ]
    }

    /// A simple generated placeholder image so the demo has real, viewable image files.
    private static func demoImage(title: String, tint: UIColor) -> Data {
        let size = CGSize(width: 800, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            tint.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 64, weight: .bold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9),
                .paragraphStyle: paragraph,
            ]
            (title as NSString).draw(
                in: CGRect(x: 0, y: size.height / 2 - 40, width: size.width, height: 80),
                withAttributes: attrs
            )
        }
        return image.pngData() ?? Data()
    }

    fileprivate func files(for repo: String) -> [String: Data] { repos[repo] ?? [:] }
    fileprivate func setFile(repo: String, path: String, data: Data) { repos[repo, default: [:]][path] = data }
    fileprivate func removeFile(repo: String, path: String) { repos[repo]?.removeValue(forKey: path) }
}

/// `RepoFiles` over the in-memory demo store.
@MainActor
struct DemoRepoClient: RepoFiles {
    let repo: String

    init(ref: RepoRef) { self.repo = ref.fullName }

    func list(_ directory: String) async throws -> [RepoEntry] {
        let prefix = directory.isEmpty ? "" : directory + "/"
        var directories = Set<String>()
        var files: [RepoEntry] = []
        for path in DemoRepoStore.shared.files(for: repo).keys where path.hasPrefix(prefix) {
            let rest = String(path.dropFirst(prefix.count))
            guard !rest.isEmpty else { continue }
            if let slash = rest.firstIndex(of: "/") {
                directories.insert(String(rest[..<slash]))
            } else {
                files.append(RepoEntry(name: rest, path: path, isDirectory: false))
            }
        }
        let dirEntries = directories.map { RepoEntry(name: $0, path: prefix + $0, isDirectory: true) }
        return (dirEntries.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
            + (files.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
    }

    func readText(_ path: String) async throws -> String {
        String(decoding: try await readData(path), as: UTF8.self)
    }

    func readData(_ path: String) async throws -> Data {
        guard let data = DemoRepoStore.shared.files(for: repo)[path] else {
            throw GitPontError.invalidProviderResponse("File not found: \(path)")
        }
        return data
    }

    func write(path: String, text: String, message: String) async throws {
        DemoRepoStore.shared.setFile(repo: repo, path: path, data: Data(text.utf8))
    }

    func writeData(path: String, data: Data, message: String) async throws {
        DemoRepoStore.shared.setFile(repo: repo, path: path, data: data)
    }

    func delete(path: String, message: String) async throws {
        DemoRepoStore.shared.removeFile(repo: repo, path: path)
    }
}
