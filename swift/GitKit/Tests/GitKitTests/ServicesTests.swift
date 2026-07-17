import XCTest
@testable import GitKit

/// Compile/link-level checks that the shared services expose a usable public API.
/// (Keychain and network calls are not exercised here — they need entitlements /
/// live endpoints; those are covered by the apps' integration tests.)
final class ServicesTests: XCTestCase {
    func testKeychainServiceIsConstructible() {
        _ = KeychainService(service: "app.hakobs.gitkit.tests", account: "token")
    }

    func testOAuthServiceIsConstructible() {
        _ = GitHubOAuthService(clientID: "test-client-id", userAgent: "GitKitTests")
    }

    func testDeviceAuthorizationValueSemantics() {
        let url = URL(string: "https://github.com/login/device")!
        let a = GitHubDeviceAuthorization(deviceCode: "d", userCode: "u", verificationURI: url, expiresIn: 900, interval: 5)
        let b = a
        XCTAssertEqual(a, b)
    }
}
