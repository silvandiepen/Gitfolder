import Foundation

/// A GitHub repository as returned by `GET /user/repos`, reduced to the fields the
/// "pick a repository" step needs. Snake-case JSON keys are mapped via `CodingKeys`
/// and a nested `owner` object.
public struct GitHubRepo: Decodable, Sendable, Identifiable, Hashable {
    public var name: String
    public var fullName: String
    public var ownerLogin: String
    public var cloneURL: URL
    public var defaultBranch: String
    public var isPrivate: Bool

    public var id: String { fullName }

    public init(
        name: String,
        fullName: String,
        ownerLogin: String,
        cloneURL: URL,
        defaultBranch: String,
        isPrivate: Bool
    ) {
        self.name = name
        self.fullName = fullName
        self.ownerLogin = ownerLogin
        self.cloneURL = cloneURL
        self.defaultBranch = defaultBranch
        self.isPrivate = isPrivate
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case fullName = "full_name"
        case owner
        case cloneURL = "clone_url"
        case defaultBranch = "default_branch"
        case isPrivate = "private"
    }

    private struct Owner: Decodable {
        var login: String
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        fullName = try container.decode(String.self, forKey: .fullName)
        ownerLogin = try container.decode(Owner.self, forKey: .owner).login
        cloneURL = try container.decode(URL.self, forKey: .cloneURL)
        defaultBranch = try container.decode(String.self, forKey: .defaultBranch)
        isPrivate = try container.decode(Bool.self, forKey: .isPrivate)
    }
}

/// Lists the signed-in user's repositories. Foundation/URLSession only, mirroring
/// `GitHubOAuthService`'s shape so it works unchanged on macOS and iOS.
public struct GitHubReposService: Sendable {
    private let session: URLSession
    private let apiBaseURL: URL
    private let userAgent: String

    public init(
        session: URLSession = .shared,
        apiBaseURL: URL = URL(string: "https://api.github.com")!,
        userAgent: String = "GitKanban"
    ) {
        self.session = session
        self.apiBaseURL = apiBaseURL
        self.userAgent = userAgent
    }

    /// List the authenticated user's repositories (owner + collaborator + org member).
    /// v1 returns the first 100 most-recently-updated repos.
    // TODO: pagination — follow the `Link: rel="next"` header to fetch beyond 100.
    public func listRepositories(token: String) async throws -> [GitHubRepo] {
        var components = URLComponents(
            url: apiBaseURL.appendingPathComponent("user/repos"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "per_page", value: "100"),
            URLQueryItem(name: "sort", value: "updated"),
            URLQueryItem(name: "affiliation", value: "owner,collaborator,organization_member"),
        ]
        guard let url = components?.url else {
            throw GitHubReposError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubReposError.invalidResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw GitHubReposError.requestFailed(status: httpResponse.statusCode)
        }
        do {
            return try JSONDecoder().decode([GitHubRepo].self, from: data)
        } catch {
            throw GitHubReposError.invalidResponse
        }
    }
}

public enum GitHubReposError: LocalizedError, Equatable, Sendable {
    case invalidResponse
    case requestFailed(status: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "GitHub returned an invalid repositories response."
        case let .requestFailed(status):
            return "GitHub returned an unexpected response (HTTP \(status))."
        }
    }
}
