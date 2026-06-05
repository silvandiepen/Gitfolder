import XCTest
@testable import GitFolder

final class ConfigStoreTests: XCTestCase {
    func testDefaultConfigUsesAppStoreLifetimeLicense() {
        let config = GitFolderConfig.empty

        XCTAssertEqual(config.license.purchaseModel, "app_store_paid_upfront")
        XCTAssertEqual(config.license.priceEur, 5)
        XCTAssertEqual(config.license.entitlement, "lifetime")
        XCTAssertFalse(config.license.subscription)
        XCTAssertFalse(config.license.inAppPurchases)
    }
}
