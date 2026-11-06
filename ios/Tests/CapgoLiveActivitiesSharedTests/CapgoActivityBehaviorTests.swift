import XCTest
@testable import CapgoLiveActivitiesShared

final class CapgoActivityBehaviorTests: XCTestCase {
    func testParseBehaviorAppearanceAndWidgetURL() throws {
        let json = """
        {"widgetUrl":"capgo://live","backgroundTint":"#FF0000","systemActionForegroundColor":"white","keyLineTint":"#00FF00"}
        """
        let behavior = CapgoActivityBehavior.parse(json: json)
        XCTAssertEqual(behavior.widgetURL?.absoluteString, "capgo://live")
        XCTAssertNotNil(behavior.backgroundTint)
        XCTAssertNotNil(behavior.systemActionForegroundColor)
        XCTAssertNotNil(behavior.keyLineTint)
    }

    func testParseBehaviorEmptyJSON() {
        let behavior = CapgoActivityBehavior.parse(json: nil)
        XCTAssertNil(behavior.widgetURL)
        XCTAssertNil(behavior.backgroundTint)
        XCTAssertNil(behavior.systemActionForegroundColor)
        XCTAssertNil(behavior.keyLineTint)
    }
}
