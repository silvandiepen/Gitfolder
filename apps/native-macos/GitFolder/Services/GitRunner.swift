import Foundation

struct GitCommandResult: Equatable {
    var exitCode: Int32
    var standardOutput: String
    var standardError: String

    var succeeded: Bool { exitCode == 0 }
}

struct GitRunner {
    func run(_ arguments: [String], in workingDirectory: URL, timeoutSeconds: TimeInterval = 30) throws -> GitCommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + arguments
        process.currentDirectoryURL = workingDirectory

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

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
}

enum GitRunnerError: LocalizedError {
    case timedOut

    var errorDescription: String? {
        switch self {
        case .timedOut:
            "Git command timed out."
        }
    }
}
