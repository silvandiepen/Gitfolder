import Foundation
import GitKitEngineSpike

// Spike harness for GITKIT-128. Runs the full clone → edit → commit → pull-rebase → push flow
// against a throwaway repo, so the libgit2/HTTPS/token path is exercised end to end on a Mac
// (and, ultimately, from an iOS device/simulator target).
//
// Run:
//   export GITKIT_SPIKE_REPO="https://github.com/<you>/gitkit-spike-throwaway.git"
//   export GITKIT_SPIKE_TOKEN="<a fine-grained token with contents:write on that repo only>"
//   swift run libgit2-spike-cli
//
// Never commit a real token. Use a throwaway repo and revoke the token after.
// (Top-level code in `main.swift` — no @main here; @main is illegal in a file named main.swift.)

func env(_ key: String) -> String? {
    guard let v = ProcessInfo.processInfo.environment[key], !v.isEmpty else { return nil }
    return v
}

func step(_ name: String, _ body: () async throws -> Void) async {
    do { try await body(); print("✅ \(name)") }
    catch let GitEngineError.notImplemented(m) { print("⏳ \(name) — TODO on Mac: \(m)") }
    catch { print("❌ \(name) — \(error)") }
}

guard let repo = env("GITKIT_SPIKE_REPO"), let token = env("GITKIT_SPIKE_TOKEN"),
      let remoteURL = URL(string: repo) else {
    FileHandle.standardError.write(Data("Set GITKIT_SPIKE_REPO and GITKIT_SPIKE_TOKEN.\n".utf8))
    exit(2)
}

let engine = Libgit2Engine()
let creds = GitCredentials(token: token)
let branch = "main"
let workdir = FileManager.default.temporaryDirectory
    .appendingPathComponent("gitkit-spike-\(UInt64(Date().timeIntervalSince1970))")

await step("clone") {
    try await engine.clone(from: remoteURL, into: workdir, credentials: creds)
}
await step("edit + commit") {
    let file = workdir.appendingPathComponent("spike-\(Int(Date().timeIntervalSince1970)).md")
    try "GitKit libgit2 spike \(Date())\n".write(to: file, atomically: true, encoding: .utf8)
    let r = try await engine.commitAll(in: workdir, message: "GitKit spike snapshot",
                                        author: Signature(name: "GitKit Spike", email: "spike@example.invalid"))
    print("   commit: \(r.sha.isEmpty ? "(no changes)" : r.sha)")
}
await step("pull --rebase") {
    try await engine.pullRebase(in: workdir, branch: branch, credentials: creds)
}
await step("push") {
    try await engine.push(in: workdir, branch: branch, credentials: creds)
}

print("\nSpike run complete. Map the ✅/❌/⏳ above to the GITKIT-128 acceptance checklist in README.md.")
