import Foundation
import GitPontCore

/// Which hosted provider a connection targets. Self-hosted GitLab carries its own
/// server URL; the others are fixed instances.
enum ProviderChoice: String, CaseIterable, Identifiable, Codable {
    case github
    case gitlabCloud
    case gitlabSelfHosted
    var id: String { rawValue }

    var title: String {
        switch self {
        case .github: return "GitHub"
        case .gitlabCloud: return "GitLab.com"
        case .gitlabSelfHosted: return "GitLab (self-hosted)"
        }
    }

    var needsServerURL: Bool { self == .gitlabSelfHosted }
}

/// An active provider connection: the git-pont provider + instance + token used for
/// every API call, plus the signed-in account login.
struct ProviderConnection {
    let choice: ProviderChoice
    let instance: GitProviderInstance
    let provider: any GitProvider
    let token: String
    let login: String

    var requestContext: GitProviderRequestContext {
        let now = Date()
        let connection = GitConnection(
            id: instance.id, instance: instance, accountID: login, accountLogin: login,
            authMethod: .personalAccessToken, createdAt: now, updatedAt: now
        )
        return GitProviderRequestContext(connection: connection, credential: GitCredential(accessToken: token))
    }
}
