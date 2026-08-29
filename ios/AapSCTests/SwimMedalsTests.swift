import XCTest
@testable import AapSC

final class SwimMedalsTests: XCTestCase {
    func testAwardsFirstSplashWithOneSession() {
        let medals = SwimMedals.evaluateAllMedals([
            TestFixtures.session(id: "1", date: "2025-06-10", metrics: TestFixtures.metrics(distanceM: 500))
        ])
        let first = medals.first { $0.id == "first_splash" }
        XCTAssertEqual(first?.earned, true)
    }

    func testAwardsFourSessionsInAWeek() {
        let sessions = [
            TestFixtures.session(id: "1", date: "2025-06-09", metrics: TestFixtures.metrics(distanceM: 1000)),
            TestFixtures.session(id: "2", date: "2025-06-10", metrics: TestFixtures.metrics(distanceM: 1000)),
            TestFixtures.session(id: "3", date: "2025-06-11", metrics: TestFixtures.metrics(distanceM: 1000)),
            TestFixtures.session(id: "4", date: "2025-06-12", metrics: TestFixtures.metrics(distanceM: 1000))
        ]
        let medals = SwimMedals.evaluateAllMedals(sessions)
        XCTAssertEqual(medals.first { $0.id == "four_sessions_week" }?.earned, true)
    }

    func testTracksMonthly10kMedalWithPeriod() {
        let sessions = (0..<5).map { i in
            TestFixtures.session(
                id: String(i),
                date: String(format: "2025-06-%02d", i + 1),
                metrics: TestFixtures.metrics(distanceM: 2100)
            )
        }
        let medals = SwimMedals.evaluateAllMedals(sessions)
        let tenK = medals.first { $0.id == "ten_k_month" }
        XCTAssertEqual(tenK?.earned, true)
        XCTAssertTrue(tenK?.periods.contains("2025-06") == true)
    }

    func testIncludesProgressForUnearnedMedals() {
        let medals = SwimMedals.evaluateAllMedals([
            TestFixtures.session(id: "1", date: "2025-06-10", metrics: TestFixtures.metrics(distanceM: 1500))
        ])
        let tenK = medals.first { $0.id == "ten_k_lifetime" }
        XCTAssertEqual(tenK?.earned, false)
        XCTAssertNotNil(tenK?.progress)
        XCTAssertEqual(tenK?.progress?.percent, 15)
        XCTAssertEqual(tenK?.progress?.current, 1500)
        XCTAssertEqual(tenK?.progress?.target, 10000)
    }

    func testAwardsHatTrickForThreeConsecutiveDays() {
        let medals = SwimMedals.evaluateAllMedals([
            TestFixtures.session(id: "1", date: "2025-06-10", metrics: TestFixtures.metrics(distanceM: 1000)),
            TestFixtures.session(id: "2", date: "2025-06-11", metrics: TestFixtures.metrics(distanceM: 1000)),
            TestFixtures.session(id: "3", date: "2025-06-12", metrics: TestFixtures.metrics(distanceM: 1000))
        ])
        XCTAssertEqual(medals.first { $0.id == "hat_trick" }?.earned, true)
    }

    func testOmitsProgressForEarnedMedals() {
        let medals = SwimMedals.evaluateAllMedals([
            TestFixtures.session(id: "1", date: "2025-06-10", metrics: TestFixtures.metrics(distanceM: 500))
        ])
        let first = medals.first { $0.id == "first_splash" }
        XCTAssertEqual(first?.earned, true)
        XCTAssertNil(first?.progress)
    }

    func testUnlocksAllMedalsWhenCheatFlagIsSet() {
        let medals = SwimMedals.evaluateAllMedals([], allMedalsUnlocked: true)
        XCTAssertTrue(medals.allSatisfy(\.earned))
        XCTAssertTrue(medals.allSatisfy { $0.earnedAt != nil })
    }

    func testAggregatesMonthlyCalories() {
        let ctx = SwimMedals.buildMedalContext([
            TestFixtures.session(id: "1", date: "2025-07-01", metrics: TestFixtures.metrics(activeKcal: 6000)),
            TestFixtures.session(id: "2", date: "2025-07-15", metrics: TestFixtures.metrics(activeKcal: 5000))
        ])
        XCTAssertTrue(ctx.monthsWith10kCal.contains("2025-07"))
    }

    func testReturnsMedalsEarnedOnlyAfterNewSession() {
        let before: [SwimSession] = []
        let after = [TestFixtures.session(id: "1", date: "2025-06-10", metrics: TestFixtures.metrics(distanceM: 500))]
        let newly = SwimMedals.getNewlyEarnedMedals(sessionsBefore: before, sessionsAfter: after)
        XCTAssertEqual(newly.count, 1)
        XCTAssertEqual(newly[0].id, "first_splash")
    }

    func testReturnsEmptyWhenNoNewMedals() {
        let sessions = [TestFixtures.session(id: "1", date: "2025-06-10", metrics: TestFixtures.metrics(distanceM: 500))]
        XCTAssertTrue(SwimMedals.getNewlyEarnedMedals(sessionsBefore: sessions, sessionsAfter: sessions).isEmpty)
    }

    func testRecordsDateOfSessionThatUnlockedMedal() {
        let sessions = [
            TestFixtures.session(id: "1", date: "2025-06-08", metrics: TestFixtures.metrics(distanceM: 500)),
            TestFixtures.session(id: "2", date: "2025-06-10", metrics: TestFixtures.metrics(distanceM: 500))
        ]
        let medals = SwimMedals.evaluateAllMedals(sessions)
        XCTAssertEqual(medals.first { $0.id == "first_splash" }?.earnedAt, "2025-06-08")
    }

    func testUsesSessionThatCompletesStreakRequirement() {
        let sessions = [
            TestFixtures.session(id: "1", date: "2025-06-10", metrics: TestFixtures.metrics(distanceM: 1000)),
            TestFixtures.session(id: "2", date: "2025-06-11", metrics: TestFixtures.metrics(distanceM: 1000)),
            TestFixtures.session(id: "3", date: "2025-06-12", metrics: TestFixtures.metrics(distanceM: 1000))
        ]
        let medals = SwimMedals.evaluateAllMedals(sessions)
        XCTAssertEqual(medals.first { $0.id == "hat_trick" }?.earnedAt, "2025-06-12")
    }
}
