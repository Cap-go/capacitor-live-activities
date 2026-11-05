import XCTest
@testable import CapgoLiveActivitiesShared

final class CapgoActivityMetadataTests: XCTestCase {
    func testEffectiveStaleDateUsesExplicitRequest() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let requested: Double = 2_000_000
        XCTAssertEqual(
            CapgoActivityMetadata.effectiveStaleDateMillis(requested: requested, storedMillis: 500_000, now: now),
            requested
        )
    }

    func testEffectiveStaleDateIgnoresExpiredStoredValue() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let expiredMillis = (now.timeIntervalSince1970 - 60) * 1000
        XCTAssertNil(
            CapgoActivityMetadata.effectiveStaleDateMillis(requested: nil, storedMillis: expiredMillis, now: now)
        )
    }

    func testEffectiveStaleDateKeepsFutureStoredValue() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let futureMillis = (now.timeIntervalSince1970 + 3600) * 1000
        XCTAssertEqual(
            CapgoActivityMetadata.effectiveStaleDateMillis(requested: nil, storedMillis: futureMillis, now: now),
            futureMillis
        )
    }
}
