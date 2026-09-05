import XCTest
@testable import AapVitality

final class VitalityFeaturesTests: XCTestCase {
    func testSleepPointsTiers() {
        let short = VitalityPoints.sleepPoints(for: 400)
        XCTAssertEqual(short.points, 0)

        let seven = VitalityPoints.sleepPoints(for: 420)
        XCTAssertEqual(seven.points, 10)

        let eight = VitalityPoints.sleepPoints(for: 480)
        XCTAssertEqual(eight.points, 15)
    }

    func testBuildDailyRecordIncludesSleepInTotal() {
        let record = VitalityPoints.buildDailyRecord(
            date: "2026-01-01",
            steps: 5000,
            sleepMinutes: 420,
            workouts: [],
            profile: .default,
            mascotId: "flo"
        )
        XCTAssertEqual(record.sleepPoints, 10)
        XCTAssertEqual(record.totalPoints, record.stepPoints + record.sleepPoints)
    }

    func testVitalityLevelsProgression() {
        let level1 = VitalityLevels.currentLevel(for: 100)
        XCTAssertEqual(level1.level, 1)
        let level3 = VitalityLevels.currentLevel(for: 2500)
        XCTAssertEqual(level3.level, 3)
    }

    func testStreakShieldAutoApply() {
        var goalState = VitalityGoalState.empty
        goalState.streakShieldMonthKey = VitalityGoals.getMonthKey()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let today = VitalityGoals.todayDateKey()
        guard let todayDate = formatter.date(from: today),
              let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: todayDate) else {
            XCTFail("date setup")
            return
        }
        let activeDate = formatter.string(from: twoDaysAgo)
        let records = [
            DailyVitalityRecord(
                id: activeDate,
                date: activeDate,
                steps: 6000,
                stepPoints: 10,
                workoutPoints: 0,
                sleepMinutes: 0,
                sleepPoints: 0,
                totalPoints: 10,
                workouts: [],
                stepTiersReached: [5000]
            )
        ]
        _ = VitalityStreak.reconcile(goalState: &goalState, records: records)
        XCTAssertEqual(goalState.streakShieldsAvailable, 0)
        XCTAssertEqual(goalState.shieldUsedDates.count, 1)
    }

    func testWorkoutTypeBadges() {
        let workout = VitalityWorkout(
            id: "w1",
            date: "2026-01-01",
            workoutType: "running",
            durationSec: 35 * 60,
            avgHeartRate: nil,
            zoneMinutes: nil,
            activeKcal: nil,
            healthKitWorkoutUUID: "w1",
            pointsEarned: 20
        )
        let record = DailyVitalityRecord(
            id: "2026-01-01",
            date: "2026-01-01",
            steps: 0,
            stepPoints: 0,
            workoutPoints: 20,
            sleepMinutes: 0,
            sleepPoints: 0,
            totalPoints: 20,
            workouts: [workout],
            stepTiersReached: []
        )
        let badges = VitalityWorkoutBadges.earnedBadges(from: [record])
        XCTAssertEqual(badges.first?.workoutType, "running")
        XCTAssertEqual(badges.first?.count, 1)
    }

    func testAchievementPathsProgress() {
        let medals = VitalityMedals.evaluateAllMedals([], profile: .default, goalState: .empty)
        let paths = VitalityPaths.progress(for: medals)
        XCTAssertEqual(paths.count, VitalityPaths.paths.count)
        XCTAssertEqual(paths.first?.completedCount, 0)
    }

    func testComputeDailyTargetUsesWeeklyAndBaseline() {
        let profile = VitalityProfile.default
        let weeklyTarget = 350
        let target = VitalityGoals.computeDailyTarget(
            weeklyTarget: weeklyTarget,
            profile: profile,
            intensity: 1
        )
        XCTAssertGreaterThanOrEqual(target, VitalityGoals.baselineDailyPoints(profile: profile))
        XCTAssertGreaterThanOrEqual(target, 50)
    }

    func testTodayPointsReturnsRecordTotal() {
        let record = DailyVitalityRecord(
            id: "2026-08-29",
            date: "2026-08-29",
            steps: 8000,
            stepPoints: 15,
            workoutPoints: 20,
            sleepMinutes: 420,
            sleepPoints: 10,
            totalPoints: 45,
            workouts: [],
            stepTiersReached: [5000, 8000]
        )
        XCTAssertEqual(
            VitalityGoals.todayPoints(records: [record], dateKey: "2026-08-29"),
            45
        )
        XCTAssertEqual(VitalityGoals.todayPoints(records: [record], dateKey: "2026-08-28"), 0)
    }

    func testDailyGoalStatusReflectsProgress() {
        let profile = VitalityProfile.default
        let goalState = VitalityGoalState.empty
        let dateKey = "2026-08-29"
        let records = [
            DailyVitalityRecord(
                id: dateKey,
                date: dateKey,
                steps: 12000,
                stepPoints: 25,
                workoutPoints: 30,
                sleepMinutes: 480,
                sleepPoints: 15,
                totalPoints: 70,
                workouts: [],
                stepTiersReached: [5000, 10000]
            )
        ]
        let status = SwimNotifications.dailyGoalStatus(
            records: records,
            profile: profile,
            goalState: goalState,
            intensity: 1,
            dateKey: dateKey
        )
        XCTAssertEqual(status.earned, 70)
        XCTAssertEqual(status.met, status.earned >= status.target)
        XCTAssertEqual(status.remaining, max(0, status.target - status.earned))
    }

    func testMonthlyGoalReminderUsesVitalityChallengesNotSwim() {
        let now = date(from: "2026-08-27")
        let monthKey = "2026-08"
        let rerolls = [
            monthKey: MonthRerollEntry(overrides: [
                "0": "workout_count",
                "1": "sleep_nights",
                "2": "steps_20k_day"
            ])
        ]
        var goalState = VitalityGoalState.empty
        goalState.monthlyTargets[monthKey] = 1000
        let t = TranslationService()
        t.setLanguage("en")

        let state = VitalityGoals.evaluatePointChallenges(
            records: [],
            profile: .default,
            goalState: goalState,
            monthKey: monthKey,
            intensity: 1,
            rerolls: rerolls,
            todayKey: "2026-08-27"
        )
        XCTAssertEqual(Set(state.challenges.map(\.type)), Set(["workout_count", "sleep_nights", "steps_20k_day"]))
        XCTAssertEqual(state.completedCount, 0)

        let reminders = SwimNotifications.monthlyGoalReminders(
            dailyRecords: [],
            profile: .default,
            goalState: goalState,
            monthlyChallengeRerolls: rerolls,
            intensity: 1,
            t: t,
            now: now
        )

        XCTAssertEqual(reminders.count, 1)
        let expectedGoals = state.challenges.prefix(2).map {
            SwimMonthlyChallengeFormatters.formatChallengeTarget($0.type, $0.target, t: t)
        }.joined(separator: ", ")
        XCTAssertEqual(
            reminders[0].body,
            t.t("notifications.monthlyGoalsBody", params: [
                "count": "3",
                "days": "\(SwimNotifications.daysRemainingInMonth(now))",
                "goals": expectedGoals,
            ])
        )
        XCTAssertFalse(expectedGoals.contains("sessions"))
    }

    func testMonthlyGoalReminderSkipsWhenVitalityChallengesAreDone() {
        let now = date(from: "2026-08-27")
        let monthKey = "2026-08"
        let rerolls = [
            monthKey: MonthRerollEntry(overrides: [
                "0": "workout_count",
                "1": "sleep_nights",
                "2": "steps_20k_day"
            ])
        ]
        var goalState = VitalityGoalState.empty
        goalState.monthlyTargets[monthKey] = 1000

        let records = (1...12).map { day -> DailyVitalityRecord in
            let date = String(format: "2026-08-%02d", day)
            let workout = VitalityWorkout(
                id: "w-\(date)",
                date: date,
                workoutType: "running",
                durationSec: 30 * 60,
                pointsEarned: 20
            )
            return DailyVitalityRecord(
                id: date,
                date: date,
                steps: day == 1 ? 20_000 : 8_000,
                stepPoints: day == 1 ? 50 : 15,
                workoutPoints: day <= 8 ? 20 : 0,
                sleepMinutes: 480,
                sleepPoints: 15,
                totalPoints: 50,
                workouts: day <= 8 ? [workout] : [],
                stepTiersReached: day == 1 ? [5000, 10000, 20000] : [5000]
            )
        }

        let state = VitalityGoals.evaluatePointChallenges(
            records: records,
            profile: .default,
            goalState: goalState,
            monthKey: monthKey,
            intensity: 1,
            rerolls: rerolls,
            todayKey: "2026-08-27"
        )
        XCTAssertEqual(state.completedCount, 3, "Test setup should complete all vitality challenges")

        let reminders = SwimNotifications.monthlyGoalReminders(
            dailyRecords: records,
            profile: .default,
            goalState: goalState,
            monthlyChallengeRerolls: rerolls,
            intensity: 1,
            t: TranslationService(),
            now: now
        )
        XCTAssertTrue(reminders.isEmpty)
    }

    func testBackgroundRefreshAimsAtDailyReminderLeadTime() {
        let morning = date(from: "2026-09-05", hour: 10, minute: 0)
        let morningNext = BackgroundTodayStepsSync.nextEarliestBeginDate(
            now: morning,
            reminderHour: 18,
            interval: 30 * 60,
            leadTime: 15 * 60
        )
        XCTAssertEqual(morningNext, morning.addingTimeInterval(30 * 60))

        let lateAfternoon = date(from: "2026-09-05", hour: 17, minute: 20)
        let lead = Calendar.current.date(
            bySettingHour: 17,
            minute: 45,
            second: 0,
            of: lateAfternoon
        )
        XCTAssertEqual(
            BackgroundTodayStepsSync.nextEarliestBeginDate(
                now: lateAfternoon,
                reminderHour: 18,
                interval: 30 * 60,
                leadTime: 15 * 60
            ),
            lead
        )

        let justBeforeReminder = date(from: "2026-09-05", hour: 17, minute: 50)
        XCTAssertEqual(
            BackgroundTodayStepsSync.nextEarliestBeginDate(
                now: justBeforeReminder,
                reminderHour: 18,
                interval: 30 * 60,
                leadTime: 15 * 60
            ),
            justBeforeReminder.addingTimeInterval(60)
        )

        let evening = date(from: "2026-09-05", hour: 23, minute: 0)
        let endOfDay = Calendar.current.date(
            bySettingHour: 23,
            minute: 30,
            second: 0,
            of: evening
        )
        XCTAssertEqual(
            BackgroundTodayStepsSync.nextEarliestBeginDate(
                now: evening,
                reminderHour: 18,
                interval: 30 * 60,
                leadTime: 15 * 60,
                lastFullDaySyncDateKey: nil
            ),
            endOfDay
        )

        let afterEndOfDay = date(from: "2026-09-05", hour: 23, minute: 40)
        XCTAssertEqual(
            BackgroundTodayStepsSync.nextEarliestBeginDate(
                now: afterEndOfDay,
                reminderHour: 18,
                interval: 30 * 60,
                leadTime: 15 * 60,
                lastFullDaySyncDateKey: nil
            ),
            afterEndOfDay.addingTimeInterval(60)
        )

        XCTAssertEqual(
            BackgroundTodayStepsSync.nextEarliestBeginDate(
                now: afterEndOfDay,
                reminderHour: 18,
                interval: 30 * 60,
                leadTime: 15 * 60,
                lastFullDaySyncDateKey: "2026-09-05"
            ),
            afterEndOfDay.addingTimeInterval(30 * 60)
        )
    }

    func testBackgroundSyncKindUsesHalfHourStepsAndHourlyWorkouts() {
        let now = date(from: "2026-09-05", hour: 10, minute: 0)
        XCTAssertEqual(
            BackgroundTodayStepsSync.syncKind(
                now: now,
                lastWorkoutSyncAt: nil,
                lastFullDaySyncDateKey: nil
            ),
            .stepsAndWorkouts
        )
        XCTAssertEqual(
            BackgroundTodayStepsSync.syncKind(
                now: now,
                lastWorkoutSyncAt: now.addingTimeInterval(-10 * 60),
                lastFullDaySyncDateKey: nil
            ),
            .steps
        )
        XCTAssertEqual(
            BackgroundTodayStepsSync.syncKind(
                now: now,
                lastWorkoutSyncAt: now.addingTimeInterval(-60 * 60),
                lastFullDaySyncDateKey: nil
            ),
            .stepsAndWorkouts
        )

        let late = date(from: "2026-09-05", hour: 23, minute: 40)
        XCTAssertEqual(
            BackgroundTodayStepsSync.syncKind(
                now: late,
                lastWorkoutSyncAt: late.addingTimeInterval(-10 * 60),
                lastFullDaySyncDateKey: nil
            ),
            .fullDay
        )
        XCTAssertEqual(
            BackgroundTodayStepsSync.syncKind(
                now: late,
                lastWorkoutSyncAt: late.addingTimeInterval(-10 * 60),
                lastFullDaySyncDateKey: "2026-09-05"
            ),
            .steps
        )
    }

    func testPointsEarnedNotificationPayload() {
        let t = TranslationService()
        t.setLanguage("en")
        XCTAssertNil(
            SwimNotifications.pointsEarnedPayload(
                previousPoints: 10,
                currentPoints: 10,
                lastNotifiedPoints: 10,
                t: t
            )
        )

        let payload = SwimNotifications.pointsEarnedPayload(
            previousPoints: 10,
            currentPoints: 25,
            lastNotifiedPoints: 10,
            t: t
        )
        XCTAssertEqual(payload?.title, t.t("notifications.pointsEarnedTitle"))
        XCTAssertEqual(
            payload?.body,
            t.t("notifications.pointsEarnedBody", params: [
                "gained": "15",
                "total": "25",
            ])
        )
        XCTAssertEqual(SwimNotifications.lastNotifiedPoints(for: "2026-09-05", stored: "2026-09-05:25"), 25)
        XCTAssertEqual(SwimNotifications.lastNotifiedPoints(for: "2026-09-05", stored: "2026-09-04:25"), 0)
    }

    private func date(from key: String, hour: Int = 0, minute: Int = 0) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let day = formatter.date(from: key) ?? Date()
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }
}
