// swift-tools-version: 5.9
// GITKIT-128 — libgit2-on-iOS spike.
// Self-contained SwiftPM package. It intentionally lives under `spikes/` and depends on
// nothing else in the monorepo so it cannot collide with the in-progress `swift/GitKit`
// extraction (GITKIT-005/006). Throwaway: its job is to answer one question, then inform
// the real Libgit2Engine on the `gitkit-swift` epic.
import PackageDescription

let package = Package(
    name: "libgit2-ios-spike",
    platforms: [
        .macOS(.v13),
        .iOS(.v17),
    ],
    products: [
        .library(name: "GitKitEngineSpike", targets: ["GitKitEngineSpike"]),
        .executable(name: "libgit2-spike-cli", targets: ["libgit2-spike-cli"]),
    ],
    dependencies: [
        // SwiftGit2 is the common libgit2 wrapper for Apple platforms and is the fastest way
        // to prove the flow. It is aging (see platforms-and-git.md); if it fights back, drop to
        // the libgit2 C API directly via a `Clibgit2` system-library/xcframework target. The
        // C-API call sequence is documented in Libgit2Engine.swift so the choice of wrapper does
        // not change what we must prove.
        .package(url: "https://github.com/SwiftGit2/SwiftGit2.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "GitKitEngineSpike",
            dependencies: [.product(name: "SwiftGit2", package: "SwiftGit2")]
        ),
        .executableTarget(
            name: "libgit2-spike-cli",
            dependencies: ["GitKitEngineSpike"]
        ),
    ]
)
