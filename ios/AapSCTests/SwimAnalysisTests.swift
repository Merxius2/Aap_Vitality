import XCTest
@testable import AapSC

final class SwimAnalysisTests: XCTestCase {
    private var t: TranslationService { TestFixtures.identityTranslator() }

    func testReturnsRichFirstSessionFeedbackWithoutAI() {
        let swim = TestFixtures.session(id: "1", date: "2025-06-10", metrics: TestFixtures.metrics(distanceM: 2000, paceSecPer100m: 120, activeKcal: 400))
        let feedback = SwimFeedback.buildPersonalFeedback(
            session: swim,
            allSessions: [swim],
            profile: TestFixtures.profile,
            t: t
        )
        XCTAssertTrue(feedback.coachMessage.contains("feedback.firstSession"))
        XCTAssertFalse(feedback.tip.isEmpty)
        XCTAssertGreaterThanOrEqual(feedback.highlights.count, 2)
        XCTAssertEqual(feedback.motivation, "feedback.motivationFirst")
    }

    func testIncludesBenchmarkAndTrendInsightsForRepeatSwimmers() {
        let sessions = [
            TestFixtures.session(id: "1", date: "2025-06-01", metrics: TestFixtures.metrics(distanceM: 2000, paceSecPer100m: 130)),
            TestFixtures.session(id: "2", date: "2025-06-05", metrics: TestFixtures.metrics(distanceM: 2200, paceSecPer100m: 128)),
            TestFixtures.session(id: "3", date: "2025-06-10", metrics: TestFixtures.metrics(distanceM: 2500, paceSecPer100m: 118, activeKcal: 500, avgHeartRate: 142))
        ]
        var profile = TestFixtures.profile
        profile.mascotId = "flo"
        let feedback = SwimFeedback.buildPersonalFeedback(session: sessions[2], allSessions: sessions, profile: profile, t: t)
        XCTAssertGreaterThanOrEqual(feedback.insights.count, 4)
        XCTAssertTrue(feedback.highlights.contains { $0.label == "feedback.highlightPace" })
        XCTAssertNotEqual(feedback.benchmarkLevel, .unknown)
        XCTAssertFalse(feedback.tip.isEmpty)
        XCTAssertFalse(feedback.coachMessage.isEmpty)
        XCTAssertFalse(feedback.motivation.isEmpty)
    }

    func testDetectsPersonalBestBadgesInMotivation() {
        let sessions = [
            TestFixtures.session(id: "1", date: "2025-06-01", metrics: TestFixtures.metrics(distanceM: 2000, paceSecPer100m: 130)),
            TestFixtures.session(id: "2", date: "2025-06-10", metrics: TestFixtures.metrics(distanceM: 2500, paceSecPer100m: 110))
        ]
        var profile = TestFixtures.profile
        profile.sex = "female"
        profile.age = 28
        let feedback = SwimFeedback.buildPersonalFeedback(session: sessions[1], allSessions: sessions, profile: profile, t: t)
        XCTAssertFalse(feedback.badges.isEmpty)
        XCTAssertEqual(feedback.motivation, "feedback.motivationPersonalBest")
    }

    func testReturnsDisappointedMoodForFinsOnSlowerSwim() {
        var sessions = (1...8).map { index in
            TestFixtures.session(
                id: String(index),
                date: String(format: "2025-05-%02d", index),
                metrics: TestFixtures.metrics(distanceM: 2000, paceSecPer100m: 95)
            )
        }
        sessions.append(TestFixtures.session(id: "10", date: "2025-06-10", metrics: TestFixtures.metrics(distanceM: 1800, paceSecPer100m: 125)))
        var profile = TestFixtures.profile
        profile.mascotId = "fins"
        let feedback = SwimFeedback.buildPersonalFeedback(session: sessions.last!, allSessions: sessions, profile: profile, t: t)
        XCTAssertEqual(feedback.mascotMood, "disappointed")
        XCTAssertEqual(feedback.motivation, "feedback.motivationPaceDownCritical")
    }

    func testKeepsFlipHappyOnModeratelySlowerSwim() {
        let sessions = [
            TestFixtures.session(id: "1", date: "2025-06-01", metrics: TestFixtures.metrics(distanceM: 2000, paceSecPer100m: 110)),
            TestFixtures.session(id: "2", date: "2025-06-10", metrics: TestFixtures.metrics(distanceM: 2000, paceSecPer100m: 120))
        ]
        var profile = TestFixtures.profile
        profile.mascotId = "flip"
        let feedback = SwimFeedback.buildPersonalFeedback(session: sessions[1], allSessions: sessions, profile: profile, t: t)
        XCTAssertEqual(feedback.mascotMood, "happy")
    }

    func testFiltersExcludedSessionsFromStatsHelpers() {
        let sessions = [
            TestFixtures.session(id: "1", date: "2025-06-01", metrics: TestFixtures.metrics(distanceM: 2000, paceSecPer100m: 130, durationSec: 2600, activeKcal: 400, laps: 80)),
            TestFixtures.session(id: "2", date: "2025-06-05", metrics: TestFixtures.metrics(distanceM: 1500, paceSecPer100m: 150, durationSec: 2250, activeKcal: 300, laps: 60), excludeFromStats: true),
            TestFixtures.session(id: "3", date: "2025-06-10", metrics: TestFixtures.metrics(distanceM: 2500, paceSecPer100m: 118, durationSec: 2950, activeKcal: 500, laps: 100))
        ]
        XCTAssertEqual(SwimAnalysis.statsSessions(sessions).count, 2)
        XCTAssertEqual(SwimAnalysis.combinedStats(sessions)?.sessionCount, 2)
        XCTAssertEqual(SwimAnalysis.combinedStats(sessions)?.totalDistanceM, 4500)
        XCTAssertEqual(SwimAnalysis.chartSessions(sessions).count, 2)
    }

    func testIgnoresExcludedSessionsForPersonalRecords() {
        let sessions = [
            TestFixtures.session(id: "1", date: "2025-06-01", metrics: TestFixtures.metrics(distanceM: 2000, paceSecPer100m: 130, durationSec: 2600, activeKcal: 400, laps: 80)),
            TestFixtures.session(id: "2", date: "2025-06-05", metrics: TestFixtures.metrics(distanceM: 1500, paceSecPer100m: 150, durationSec: 2250, activeKcal: 300, laps: 60), excludeFromStats: true),
            TestFixtures.session(id: "3", date: "2025-06-10", metrics: TestFixtures.metrics(distanceM: 2500, paceSecPer100m: 118, durationSec: 2950, activeKcal: 500, laps: 100))
        ]
        let records = SwimRecords.getPersonalRecords(sessions)!
        XCTAssertEqual(records.fastestPace?.sessionId, "3")
        XCTAssertEqual(records.longestDistance?.sessionId, "3")
    }

    func testStillAnalyzesExcludedSessionsWithoutPollutingCombinedStats() {
        let sessions = [
            TestFixtures.session(id: "1", date: "2025-06-01", metrics: TestFixtures.metrics(distanceM: 2000, paceSecPer100m: 130, durationSec: 2600, activeKcal: 400, laps: 80)),
            TestFixtures.session(id: "2", date: "2025-06-05", metrics: TestFixtures.metrics(distanceM: 1500, paceSecPer100m: 150, durationSec: 2250, activeKcal: 300, laps: 60), excludeFromStats: true),
            TestFixtures.session(id: "3", date: "2025-06-10", metrics: TestFixtures.metrics(distanceM: 2500, paceSecPer100m: 118, durationSec: 2950, activeKcal: 500, laps: 100))
        ]
        _ = SwimFeedback.buildPersonalFeedback(session: sessions[1], allSessions: sessions, profile: TestFixtures.profile, t: t)
        let combined = SwimAnalysis.combinedStats(sessions)!
        XCTAssertEqual(combined.sessionCount, 2)
        XCTAssertEqual(combined.totalDistanceM, 4500)
    }

    func testFiltersSessionsByChartScope() {
        let sessions = [
            TestFixtures.session(id: "1", date: "2025-01-15", metrics: TestFixtures.metrics(distanceM: 1000)),
            TestFixtures.session(id: "2", date: "2025-06-01", metrics: TestFixtures.metrics(distanceM: 2000)),
            TestFixtures.session(id: "3", date: "2025-06-10", metrics: TestFixtures.metrics(distanceM: 2500)),
        ]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let reference = calendar.date(from: DateComponents(year: 2025, month: 6, day: 15))!

        XCTAssertEqual(SwimAnalysis.filterSessions(sessions, scope: .allTime).count, 3)
        XCTAssertEqual(
            SwimAnalysis.filterSessions(sessions, scope: .month, referenceDate: reference, calendar: calendar).map(\.id),
            ["2", "3"]
        )
        XCTAssertEqual(
            SwimAnalysis.filterSessions(sessions, scope: .ytd, referenceDate: reference, calendar: calendar).count,
            3
        )
        XCTAssertEqual(
            SwimAnalysis.filterSessions(sessions, scope: .quarter, referenceDate: reference, calendar: calendar).map(\.id),
            ["2", "3"]
        )
    }
}
