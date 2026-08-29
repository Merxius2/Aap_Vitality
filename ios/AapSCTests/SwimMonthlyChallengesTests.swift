import XCTest
@testable import AapSC

final class SwimMonthlyChallengesTests: XCTestCase {
    func testGeneratesThreeDeterministicChallengesPerMonth() {
        let a = SwimMonthlyChallenges.generateMonthlyChallenges(sessions: [], monthKey: "2025-06")
        let b = SwimMonthlyChallenges.generateMonthlyChallenges(sessions: [], monthKey: "2025-06")
        let c = SwimMonthlyChallenges.generateMonthlyChallenges(sessions: [], monthKey: "2025-07")
        XCTAssertEqual(a.count, 3)
        XCTAssertEqual(a.map(\.type), b.map(\.type))
        XCTAssertNotEqual(a.map(\.type), c.map(\.type))
    }

    func testAwardsBronzeWithOneChallengeComplete() {
        let sessions = [
            TestFixtures.session(id: "1", date: "2025-06-01", metrics: TestFixtures.metrics(distanceM: 2000, activeKcal: 400)),
            TestFixtures.session(id: "2", date: "2025-06-03", metrics: TestFixtures.metrics(distanceM: 2000, activeKcal: 400)),
            TestFixtures.session(id: "3", date: "2025-06-05", metrics: TestFixtures.metrics(distanceM: 2000, activeKcal: 400)),
            TestFixtures.session(id: "4", date: "2025-06-07", metrics: TestFixtures.metrics(distanceM: 2000, activeKcal: 400))
        ]
        let state = SwimMonthlyChallenges.evaluateMonthlyChallenges(sessions: sessions, monthKey: "2025-06")
        XCTAssertGreaterThanOrEqual(state.completedCount, 1)
        XCTAssertTrue(["bronze", "silver", "gold"].contains(state.tier ?? ""))
    }

    func testDetectsTierUpgradeAfterNewSession() {
        let before = [TestFixtures.session(id: "1", date: "2025-06-01", metrics: TestFixtures.metrics(distanceM: 500))]
        let after = before + [
            TestFixtures.session(id: "2", date: "2025-06-02", metrics: TestFixtures.metrics(distanceM: 2500, activeKcal: 800)),
            TestFixtures.session(id: "3", date: "2025-06-04", metrics: TestFixtures.metrics(distanceM: 2500, activeKcal: 800)),
            TestFixtures.session(id: "4", date: "2025-06-06", metrics: TestFixtures.metrics(distanceM: 2500, activeKcal: 800))
        ]
        if let upgrade = SwimMonthlyChallenges.getMonthlyTierUpgrade(sessionsBefore: before, sessionsAfter: after, monthKey: "2025-06") {
            XCTAssertGreaterThanOrEqual(SwimMonthlyChallenges.tierRank(upgrade.tier), 1)
        }
    }

    func testListsEarnedMonthsInHistory() {
        let sessions = (0..<6).map { i in
            TestFixtures.session(
                id: String(i),
                date: String(format: "2025-06-%02d", i + 1),
                metrics: TestFixtures.metrics(distanceM: 3000, activeKcal: 600)
            )
        }
        let history = SwimMonthlyChallenges.getMonthlyChallengeHistory(sessions: sessions)
        XCTAssertEqual(history.first?.monthKey, "2025-06")
        XCTAssertNotNil(history.first?.tier)
    }

    func testReturnsOneMedalTierPerMonthForYear() {
        let sessions = [
            TestFixtures.session(id: "1", date: "2025-01-05", metrics: TestFixtures.metrics(distanceM: 3000, activeKcal: 600)),
            TestFixtures.session(id: "2", date: "2025-03-10", metrics: TestFixtures.metrics(distanceM: 3000, activeKcal: 600))
        ]
        let year = SwimMonthlyChallenges.getMonthlyMedalsForYear(sessions: sessions, year: 2025)
        XCTAssertEqual(year.count, 12)
        XCTAssertTrue(year.contains { $0.hasSessions })
    }

    func testAddsPreviewBronzeSilverGoldMonthsWhenCheatEnabled() {
        var components = DateComponents()
        components.year = 2025
        components.month = 6
        components.day = 15
        let date = Calendar.current.date(from: components)!
        let preview = SwimMonthlyChallenges.getPreviewMonthlyMedalHistoryForTesting(date: date)
        XCTAssertEqual(preview.count, 3)
        XCTAssertEqual(preview[0].tier, "gold")
        XCTAssertEqual(preview[1].tier, "silver")
        XCTAssertEqual(preview[2].tier, "bronze")
        XCTAssertTrue(preview.allSatisfy(\.isPreview))

        let merged = SwimMonthlyChallenges.getMonthlyChallengeHistory(sessions: [], previewMonthlyMedals: true)
        XCTAssertEqual(merged.count, 3)
    }

    func testRerollsOneChallengePerMonthWithNewUnusedType() {
        let monthKey = "2025-06"
        let base = SwimMonthlyChallenges.generateMonthlyChallenges(sessions: [], monthKey: monthKey)
        let override = SwimMonthlyChallenges.createMonthlyChallengeReroll(sessions: [], monthKey: monthKey, tierIndex: 0)!
        XCTAssertEqual(override.tierIndex, 0)
        XCTAssertNotEqual(override.type, base[0].type)

        let rerolls = [monthKey: MonthRerollEntry(overrides: ["0": override.type], freeUses: 1)]
        let after = SwimMonthlyChallenges.generateMonthlyChallenges(sessions: [], monthKey: monthKey, rerolls: rerolls)
        XCTAssertEqual(after[0].type, override.type)
        XCTAssertEqual(after[1].type, base[1].type)
        XCTAssertEqual(after[2].type, base[2].type)
        XCTAssertTrue(SwimMonthlyChallenges.hasMonthlyChallengeReroll(monthKey, rerolls: rerolls))
        XCTAssertFalse(SwimMonthlyChallenges.canRerollMonthlyChallenge(sessions: [], monthKey: monthKey, tierIndex: 1, rerolls: rerolls))
        XCTAssertFalse(SwimMonthlyChallenges.hasRerollAvailability(monthKey: monthKey, rerolls: rerolls))
    }

    func testAllowsSecondFreeRerollWhenCoachGrantsTwo() {
        let monthKey = "2025-06"
        let rerolls = [monthKey: MonthRerollEntry(overrides: ["0": "kcal"], freeUses: 1)]
        XCTAssertFalse(SwimMonthlyChallenges.hasRerollAvailability(monthKey: monthKey, rerolls: rerolls, freeLimit: 1))
        XCTAssertTrue(SwimMonthlyChallenges.hasRerollAvailability(monthKey: monthKey, rerolls: rerolls, freeLimit: 2))
        XCTAssertTrue(SwimMonthlyChallenges.canRerollMonthlyChallenge(
            sessions: [], monthKey: monthKey, tierIndex: 1, rerolls: rerolls, freeLimit: 2
        ))
    }

    func testScalesChallengeTargetsWithCoachIntensity() {
        let monthKey = "2025-06"
        let easy = SwimMonthlyChallenges.generateMonthlyChallenges(sessions: [], monthKey: monthKey, intensity: 0.75)
        let normal = SwimMonthlyChallenges.generateMonthlyChallenges(sessions: [], monthKey: monthKey, intensity: 1)
        let hard = SwimMonthlyChallenges.generateMonthlyChallenges(sessions: [], monthKey: monthKey, intensity: 1.25)
        for i in 0..<3 {
            XCTAssertLessThanOrEqual(easy[i].target, normal[i].target)
            XCTAssertGreaterThanOrEqual(hard[i].target, normal[i].target)
        }
        XCTAssertTrue(hard.enumerated().contains { $0.element.target > easy[$0.offset].target })
    }

    func testBlocksRerollOnCompletedChallenges() {
        let monthKey = "2025-06"
        let sessions = (0..<8).map { i in
            TestFixtures.session(
                id: String(i),
                date: String(format: "2025-06-%02d", i + 1),
                metrics: TestFixtures.metrics(distanceM: 3000, activeKcal: 800)
            )
        }
        let state = SwimMonthlyChallenges.evaluateMonthlyChallenges(sessions: sessions, monthKey: monthKey)
        if let completedIndex = state.challenges.firstIndex(where: \.completed) {
            XCTAssertFalse(SwimMonthlyChallenges.canRerollMonthlyChallenge(
                sessions: sessions, monthKey: monthKey, tierIndex: completedIndex
            ))
        }
    }

    func testNormalizesLegacyRerollEntriesToOverridesFormat() throws {
        let json = """
        {
          "2025-06": {"tierIndex": 0, "type": "kcal"},
          "2025-07": {"overrides": {"1": "distance"}, "freeUsed": false},
          "2025-08": {"overrides": {"0": "sessions"}, "freeUsed": true}
        }
        """
        let decoded = try JSONDecoder().decode([String: MonthRerollEntry].self, from: Data(json.utf8))
        let normalized = SwimMonthlyChallenges.normalizeMonthlyChallengeRerolls(decoded)
        XCTAssertEqual(normalized["2025-06"], MonthRerollEntry(overrides: ["0": "kcal"], freeUses: 1))
        XCTAssertEqual(normalized["2025-07"], MonthRerollEntry(overrides: ["1": "distance"], freeUses: 0))
        XCTAssertEqual(normalized["2025-08"], MonthRerollEntry(overrides: ["0": "sessions"], freeUses: 1))
        XCTAssertEqual(SwimMonthlyChallenges.normalizeMonthRerollEntry(nil), .empty)
    }
}
