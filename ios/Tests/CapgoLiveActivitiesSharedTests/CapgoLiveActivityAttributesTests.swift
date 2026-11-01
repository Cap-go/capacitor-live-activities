import XCTest
@testable import CapgoLiveActivitiesShared

final class CapgoLiveActivityAttributesTests: XCTestCase {
    func testContentStateEncodesDataWrapper() throws {
        let state = CapgoLiveActivityAttributes.ContentState(
            data: ["status": .string("Delivered")]
        )
        let data = try JSONEncoder().encode(state)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(object?["data"] as? [String: Any], ["status": "Delivered"])
    }
}
