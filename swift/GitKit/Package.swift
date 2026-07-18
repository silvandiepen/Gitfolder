// swift-tools-version: 5.9
import PackageDescription

// GitKit — the shared Swift package for GitKit's native apps (GitFolder, GitKanban).
//
// Owns the git engine and app services, plus the GitKanban board model that mirrors
// @gitkit/gitkanban-core. See project-assets/GitKanban/plan and Tasks/GitKit board.
let package = Package(
    name: "GitKit",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "GitKit", targets: ["GitKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0")
    ],
    targets: [
        .target(name: "GitKit", dependencies: ["Yams"]),
        .testTarget(name: "GitKitTests", dependencies: ["GitKit"])
    ]
)
