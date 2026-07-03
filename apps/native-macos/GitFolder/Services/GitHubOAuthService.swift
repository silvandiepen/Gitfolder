import Foundation

struct GitHubDeviceAuthorization: Equatable, Sendable {
    var deviceCode: String
    var userCode: String
    var verificationURI: URL
    var expiresIn: Int
    var interval: Int
}

struct GitHubOAuthService: Sendable {
    private let clientID: String
    private let scope: String
    private let session: URLSession

    init(
        clientID: String = "Ov23li24tWFt7qLuLqCe",
        scope: String = "repo",
        session: URLSession = .shared
    ) {
        self.clientID = clientID
        self.scope = scope
        self.session = session
    }

    func requestDeviceAuthorization() async throws -> GitHubDeviceAuthorization {
        var request = URLRequest(url: URL(string: "https://github.com/login/device/code")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody([
            "client_id": clientID,
            "scope": scope
        ])

        let response: DeviceCodeResponse = try await decodedResponse(for: request)
        guard let verificationURI = URL(string: response.verificationUri) else {
            throw GitHubOAuthError.invalidResponse
        }
        return GitHubDeviceAuthorization(
            deviceCode: response.deviceCode,
            userCode: response.userCode,
            verificationURI: verificationURI,
            expiresIn: response.expiresIn,
            interval: response.interval ?? 5
        )
    }

    func waitForAccessToken(authorization: GitHubDeviceAuthorization) async throws -> String {
        let startedAt = Date()
        var pollInterval = max(authorization.interval, 5)

        while Date().timeIntervalSince(startedAt) < TimeInterval(authorization.expiresIn) {
            try await Task.sleep(for: .seconds(pollInterval))

            var request = URLRequest(url: URL(string: "https://github.com/login/oauth/access_token")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = formBody([
                "client_id": clientID,
                "device_code": authorization.deviceCode,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
            ])

            let response: AccessTokenResponse = try await decodedResponse(for: request)
            if let accessToken = response.accessToken, !accessToken.isEmpty {
                return accessToken
            }

            switch response.error {
            case nil, "authorization_pending":
                continue
            case "slow_down":
                pollInterval += 5
            case "expired_token":
                throw GitHubOAuthError.expired
            case "access_denied":
                throw GitHubOAuthError.denied
            default:
                throw GitHubOAuthError.failed(response.errorDescription ?? response.error ?? "GitHub authorization failed.")
            }
        }

        throw GitHubOAuthError.expired
    }

    func loadViewerLogin(token: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.github.com/user")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("GitFolder", forHTTPHeaderField: "User-Agent")

        let response: GitHubViewerResponse = try await decodedResponse(for: request)
        return response.login
    }

    private func decodedResponse<T: Decodable>(for request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            if let errorResponse = try? JSONDecoder.githubOAuth.decode(OAuthErrorResponse.self, from: data) {
                throw GitHubOAuthError.failed(errorResponse.errorDescription ?? errorResponse.error)
            }
            throw GitHubOAuthError.failed("GitHub returned an unexpected response.")
        }
        do {
            return try JSONDecoder.githubOAuth.decode(T.self, from: data)
        } catch {
            throw GitHubOAuthError.invalidResponse
        }
    }

    private func formBody(_ values: [String: String]) -> Data {
        values
            .map { key, value in "\(percentEncode(key))=\(percentEncode(value))" }
            .joined(separator: "&")
            .data(using: .utf8) ?? Data()
    }

    private func percentEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }
}

enum GitHubOAuthError: LocalizedError, Equatable, Sendable {
    case denied
    case expired
    case failed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .denied:
            "GitHub authorization was cancelled."
        case .expired:
            "GitHub authorization expired. Try connecting again."
        case .failed(let message):
            message
        case .invalidResponse:
            "GitHub returned an invalid authorization response."
        }
    }
}

private struct DeviceCodeResponse: Decodable {
    var deviceCode: String
    var userCode: String
    var verificationUri: String
    var expiresIn: Int
    var interval: Int?
}

private struct AccessTokenResponse: Decodable {
    var accessToken: String?
    var tokenType: String?
    var scope: String?
    var error: String?
    var errorDescription: String?
}

private struct OAuthErrorResponse: Decodable {
    var error: String
    var errorDescription: String?
}

private struct GitHubViewerResponse: Decodable {
    var login: String
}

private extension JSONDecoder {
    static var githubOAuth: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}
