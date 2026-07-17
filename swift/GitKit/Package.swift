// swift-tools-version: 5.9
import PackageDescription

// GitKit — the shared Swift package for GitKit's native apps (GitFolder, GitKanban).
//
// Scaffold. The plan is to move GitFolder's inline services (git engine, config store,
// keychain, GitHub OAuth, folder access) into this package so both apps share one
// implementation. Tracked on the GitKit tasks board.
let package = Package(
    name: "GitKit",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "GitKit", targets: ["GitKit"])
    ],
    targets: [
        .target(name: "GitKit"),
        .testTarget(name: "GitKitTests", dependencies: ["GitKit"])
    ]
)
