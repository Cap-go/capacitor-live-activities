import XCTest
@testable import CapgoLiveActivitiesPlugin

final class CapgoLiveActivitiesPluginTests: XCTestCase {
    func testPluginVersion() throws {
        // Basic test to ensure plugin loads
        XCTAssertNotNil(CapgoLiveActivitiesPlugin.self)
    }
}
