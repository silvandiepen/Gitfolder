import Foundation

protocol GitRunning: Sendable {
    func run(
        _ arguments: [String],
        in workingDirectory: URL,
        timeoutSeconds: TimeInterval,
        environment: [String: String]
    ) throws -> GitCommandResult
}

struct GitCommandResult: Equatable, Sendable {
    var exitCode: Int32
    var standardOutput: String
    var standardError: String

    var succeeded: Bool { exitCode == 0 }
}

struct GitRunner: GitRunning {
    private let gitExecutableURL: URL

    init(gitExecutableURL: URL = GitRunner.defaultGitExecutableURL()) {
        self.gitExecutableURL = gitExecutableURL
    }

    func run(
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

        do {
            try process.run()
        } catch {
            throw GitRunnerError.launchFailed(gitExecutableURL.path, error.localizedDescription)
        }

        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }

        if process.isRunning {
            process.terminate()
            throw GitRunnerError.timedOut
        }

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        return GitCommandResult(exitCode: process.terminationStatus, standardOutput: output, standardError: error)
    }

    private static func defaultGitExecutableURL() -> URL {
        let candidates = [
            "/Library/Developer/CommandLineTools/usr/bin/git",
            "/Applications/Xcode.app/Contents/Developer/usr/bin/git",
            "/usr/local/bin/git",
            "/opt/homebrew/bin/git"
        ]

        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return URL(fileURLWithPath: candidate)
        }

        return URL(fileURLWithPath: "/usr/bin/git")
    }
}

enum GitRunnerError: LocalizedError, Sendable {
    case launchFailed(String, String)
    case timedOut

    var errorDescription: String? {
        switch self {
        case .launchFailed(let path, let details):
            "Could not launch Git at \(path). \(details)"
        case .timedOut:
            "Git command timed out."
        }
    }
}
