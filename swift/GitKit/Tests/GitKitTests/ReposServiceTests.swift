import XCTest
@testable import GitKit

final class ReposServiceTests: XCTestCase {
    func testReposServiceIsConstructible() {
        _ = GitHubReposService(userAgent: "GitKitTests")
    }

    func testDecodesUserReposArray() throws {
        let json = """
        [
          {
            "name": "gitfolder",
            "full_name": "sil/gitfolder",
            "private": false,
            "owner": { "login": "sil", "id": 1 },
            "clone_url": "https://github.com/sil/gitfolder.git",
            "default_branch": "main"
          },
          {
            "name": "secret-lab",
            "full_name": "acme/secret-lab",
            "private": true,
            "owner": { "login": "acme", "id": 2 },
            "clone_url": "https://github.com/acme/secret-lab.git",
            "default_branch": "develop"
          }
        ]
        """
        let repos = try JSONDecoder().decode([GitHubRepo].self, from: Data(json.utf8))
        XCTAssertEqual(repos.count, 2)

        let first = repos[0]
        XCTAssertEqual(first.name, "gitfolder")
        XCTAssertEqual(first.fullName, "sil/gitfolder")
        XCTAssertEqual(first.id, "sil/gitfolder")
        XCTAssertEqual(first.ownerLogin, "sil")
        XCTAssertEqual(first.cloneURL, URL(string: "https://github.com/sil/gitfolder.git"))
        XCTAssertEqual(first.defaultBranch, "main")
        XCTAssertFalse(first.isPrivate)

        let second = repos[1]
        XCTAssertEqual(second.ownerLogin, "acme")
        XCTAssertEqual(second.defaultBranch, "develop")
        XCTAssertTrue(second.isPrivate)
    }
}
