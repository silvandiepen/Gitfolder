import Foundation

/// Result of running a `git` subprocess.
public struct GitCommandResult: Equatable, Sendable {
    public var exitCode: Int32
    public var standardOutput: String
    public var standardError: String
    public var succeeded: Bool { exitCode == 0 }

    public init(exitCode: Int32, standardOutput: String, standardError: String) {
        self.exitCode = exitCode
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

/// Runs the `git` binary as a subprocess. Ported from GitFolder's `GitRunner`
/// so the shared package owns one implementation. macOS/iOS-Linux capable
/// (Foundation `Process`), which also lets the tests run on a plain runner.
public struct GitProcessRunner: Sendable {
    private let gitExecutableURL: URL

    public init(gitExecutableURL: URL = GitProcessRunner.defaultGitExecutableURL()) {
        self.gitExecutableURL = gitExecutableURL
    }

    @discardableResult
    public func run(
        _ arguments: [String],
        in workingDirectory: URL,
        timeoutSeconds: TimeInterval = 30,
        environment: [String: String] = [:]
    ) throws -> GitCommandResult {
        let process = Process()
        process.executableURL = gitExecutableURL
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Drain both pipes on background queues *before* waiting, so a large
        // output cannot deadlock the child against a full pipe buffer.
        let outBox = Box()
        let errBox = Box()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "gitkit.pipe.read", attributes: .concurrent)

        do {
            try process.run()
        } catch {
            throw GitEngineError.launchFailed(gitExecutableURL.path, error.localizedDescription)
        }

        group.enter()
        queue.async {
            outBox.value = outputPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        queue.async {
            errBox.value = errorPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        if process.isRunning {
            process.terminate()
            throw GitEngineError.timedOut
        }

        // The reads finish once the child closes its pipe ends (i.e. on exit).
        group.wait()
        let output = String(data: outBox.value, encoding: .utf8) ?? ""
        let error = String(data: errBox.value, encoding: .utf8) ?? ""
        return GitCommandResult(exitCode: process.terminationStatus, standardOutput: output, standardError: error)
    }

    private final class Box: @unchecked Sendable { var value = Data() }

    public static func defaultGitExecutableURL() -> URL {
        let candidates = [
            "/Library/Developer/CommandLineTools/usr/bin/git",
            "/Applications/Xcode.app/Contents/Developer/usr/bin/git",
            "/usr/local/bin/git",
            "/opt/homebrew/bin/git",
            "/usr/bin/git"
        ]
        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return URL(fileURLWithPath: candidate)
        }
        return URL(fileURLWithPath: "/usr/bin/git")
    }
}
