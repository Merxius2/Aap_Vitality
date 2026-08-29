import XCTest
@testable import AapSC

final class MascotMoodTests: XCTestCase {
    func testStaysHappyOnFirstSessionOrPersonalBest() {
        XCTAssertEqual(SwimFeedback.resolveSessionMascotMood(
            mascotId: "fins", isFirst: true, hasPb: false,
            paceDeltaVsPrevious: nil, usedCriticalCoachLine: false, usedPaceDownMotivation: false
        ), "happy")
        XCTAssertEqual(SwimFeedback.resolveSessionMascotMood(
            mascotId: "fins", isFirst: false, hasPb: true,
            paceDeltaVsPrevious: nil, usedCriticalCoachLine: false, usedPaceDownMotivation: false
        ), "happy")
    }

    func testKeepsFlipHappyEvenOnSlowerSwim() {
        XCTAssertEqual(SwimFeedback.resolveSessionMascotMood(
            mascotId: "flip", isFirst: false, hasPb: false,
            paceDeltaVsPrevious: -9, usedCriticalCoachLine: false, usedPaceDownMotivation: false
        ), "happy")
    }

    func testShowsFloDisappointedOnSlowerSwim() {
        XCTAssertEqual(SwimFeedback.resolveSessionMascotMood(
            mascotId: "flo", isFirst: false, hasPb: false,
            paceDeltaVsPrevious: -6, usedCriticalCoachLine: false, usedPaceDownMotivation: true
        ), "disappointed")
    }

    func testShowsFinsDisappointedOnCriticalFeedback() {
        XCTAssertEqual(SwimFeedback.resolveSessionMascotMood(
            mascotId: "fins", isFirst: false, hasPb: false,
            paceDeltaVsPrevious: -6, usedCriticalCoachLine: true, usedPaceDownMotivation: true
        ), "disappointed")
    }
}
