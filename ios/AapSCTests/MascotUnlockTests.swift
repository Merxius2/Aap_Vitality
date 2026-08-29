import XCTest
@testable import AapSC

final class MascotUnlockTests: XCTestCase {
    func testUnlocksFlipFromTheStart() {
        XCTAssertTrue(MascotUnlock.isUnlocked(
            mascotId: "flip",
            profile: TestFixtures.profile,
            sessions: []
        ))
    }

    func testLocksFloWithoutIntermediatePaceOrEnoughMonthlyMedals() {
        let sessions = [TestFixtures.makeSession(date: "2025-06-01", paceSecPer100m: 170)]
        let status = MascotUnlock.unlockStatus(mascotId: "flo", profile: TestFixtures.profile, sessions: sessions)
        XCTAssertFalse(status.unlocked)
        XCTAssertEqual(status.paceLevel, .developing)
    }

    func testUnlocksFloWithIntermediatePace() {
        let sessions = [TestFixtures.makeSession(date: "2025-06-01", paceSecPer100m: 128)]
        XCTAssertTrue(MascotUnlock.isUnlocked(mascotId: "flo", profile: TestFixtures.profile, sessions: sessions))
    }

    func testUnlocksFloWithFiveMonthlyMedals() {
        var sessions: [SwimSession] = []
        for month in 1...5 {
            let monthKey = String(format: "%02d", month)
            for day in stride(from: 1, through: 6, by: 1) {
                sessions.append(TestFixtures.makeSession(
                    date: "2025-\(monthKey)-\(String(format: "%02d", day))",
                    paceSecPer100m: 170
                ))
            }
        }
        XCTAssertEqual(MascotUnlock.countMonthlyMedals(sessions: sessions), 5)
        XCTAssertTrue(MascotUnlock.isUnlocked(mascotId: "flo", profile: TestFixtures.profile, sessions: sessions))
    }

    func testUnlocksFinsWithAdvancedPace() {
        let sessions = [TestFixtures.makeSession(date: "2025-06-01", paceSecPer100m: 100)]
        XCTAssertTrue(MascotUnlock.isUnlocked(mascotId: "fins", profile: TestFixtures.profile, sessions: sessions))
    }

    func testResolvesToFlipWhenRequestedMascotIsLocked() {
        var lockedProfile = TestFixtures.profile
        lockedProfile.sex = "female"
        lockedProfile.mascotId = "flo"
        XCTAssertEqual(MascotUnlock.resolveMascotId(profile: lockedProfile, sessions: []), "flip")
    }

    func testAllowsMascotSwitchBeforeFirstSessionOfMonth() {
        var profile = TestFixtures.profile
        profile.mascotSwitchMonthKey = nil
        let result = MascotUnlock.canSwitchMascot(
            profile: profile,
            sessions: [TestFixtures.makeSession(date: "2025-05-20", paceSecPer100m: 128)],
            monthKey: "2025-06",
            nextMascotId: "flo",
            currentMascotId: "flip"
        )
        XCTAssertTrue(result.allowed)
    }

    func testBlocksMascotSwitchAfterFirstSessionOfMonth() {
        var profile = TestFixtures.profile
        profile.mascotSwitchMonthKey = nil
        let result = MascotUnlock.canSwitchMascot(
            profile: profile,
            sessions: [TestFixtures.makeSession(date: "2025-06-02", paceSecPer100m: 128)],
            monthKey: "2025-06",
            nextMascotId: "flo",
            currentMascotId: "flip"
        )
        XCTAssertFalse(result.allowed)
        XCTAssertEqual(result.reason, "afterFirstSession")
    }

    func testBlocksSecondMascotSwitchInSameMonth() {
        var profile = TestFixtures.profile
        profile.mascotId = "flo"
        profile.mascotSwitchMonthKey = "2025-06"
        let result = MascotUnlock.canSwitchMascot(
            profile: profile,
            sessions: [],
            monthKey: "2025-06",
            nextMascotId: "flip",
            currentMascotId: "flo"
        )
        XCTAssertFalse(result.allowed)
        XCTAssertEqual(result.reason, "alreadySwitched")
    }

    func testDerivesUserPaceLevelFromAveragePace() {
        let sessions = [
            TestFixtures.makeSession(date: "2025-06-01", paceSecPer100m: 140),
            TestFixtures.makeSession(date: "2025-06-08", paceSecPer100m: 120)
        ]
        XCTAssertEqual(MascotUnlock.userSwimPaceLevel(profile: TestFixtures.profile, sessions: sessions), .intermediate)
    }
}
