import Foundation

public enum GitEngineError: LocalizedError, Sendable {
    case launchFailed(String, String)
    case timedOut
    case commandFailed(command: String, exitCode: Int32, stderr: String)
    case nothingToCommit
    case noUpstream

    public var errorDescription: String? {
        switch self {
        case let .launchFailed(path, details):
            return "Could not launch Git at \(path). \(details)"
        case .timedOut:
            return "Git command timed out."
        case let .commandFailed(command, exitCode, stderr):
            return "git \(command) failed (\(exitCode)): \(stderr)"
        case .nothingToCommit:
            return "Nothing to commit."
        case .noUpstream:
            return "No upstream branch is configured."
        }
    }
}
