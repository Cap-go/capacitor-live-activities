import XCTest
@testable import CapgoLiveActivitiesShared

final class CapgoTimerLogicTests: XCTestCase {
    func testPausesOnReachAfterTargetUsesPausedZeroDisplay() {
        let target = Date(timeIntervalSince1970: 1_000)
        let now = Date(timeIntervalSince1970: 2_000)
        XCTAssertTrue(CapgoTimerLogic.usesPausedZeroWhenReached(pausesOnReach: true, target: target, now: now))
    }

    func testPausesOnReachBeforeTargetDoesNotUsePausedZeroDisplay() {
        let target = Date(timeIntervalSince1970: 2_000)
        let now = Date(timeIntervalSince1970: 1_000)
        XCTAssertFalse(CapgoTimerLogic.usesPausedZeroWhenReached(pausesOnReach: true, target: target, now: now))
    }

    func testWithoutPausesOnReachAfterTargetDoesNotUsePausedZeroDisplay() {
        let target = Date(timeIntervalSince1970: 1_000)
        let now = Date(timeIntervalSince1970: 2_000)
        XCTAssertFalse(CapgoTimerLogic.usesPausedZeroWhenReached(pausesOnReach: false, target: target, now: now))
    }

    func testPausedZeroTimerIntervalEndsAtTarget() {
        let target = Date(timeIntervalSince1970: 1_700_000_000)
        let interval = CapgoTimerLogic.pausedZeroTimerInterval(target: target)
        XCTAssertEqual(interval.upperBound, target)
        XCTAssertEqual(interval.lowerBound, target.addingTimeInterval(-1))
    }
}
