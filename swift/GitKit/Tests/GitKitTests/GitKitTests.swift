import XCTest
@testable import GitKit

final class GitKitTests: XCTestCase {
    func testPullResultDefaults() {
        let result = PullResult(updated: true)
        XCTAssertTrue(result.updated)
        XCTAssertTrue(result.conflicts.isEmpty)
    }
}
