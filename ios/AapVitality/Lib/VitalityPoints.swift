import Foundation

enum VitalityPoints {
    static let stepMilestones = [5000, 10000, 20000]
    static let stepMilestonePoints = [10, 15, 25]
    static let sleepMilestonesMinutes = [420, 480]
    static let sleepMilestonePoints = [10, 5]
    static let minWorkoutMinutes = 30
    static let baseWorkoutPoints = 20
    static let pointsPerFiveExtraMinutes = 2
    static let zoneBonusPerMinute = [1, 2, 4, 6, 8]

    static func stepPoints(for steps: Int) -> (points: Int, tiersReached: [Int]) {
        var points = 0
        var tiers: [Int] = []
        for (index, milestone) in stepMilestones.enumerated() where steps >= milestone {
            points += stepMilestonePoints[index]
            tiers.append(milestone)
        }
        return (points, tiers)
    }

    static func sleepPoints(for minutes: Int) -> (points: Int, tiersReached: [Int]) {
        var points = 0
        var tiers: [Int] = []
        for (index, milestone) in sleepMilestonesMinutes.enumerated() where minutes >= milestone {
            points += sleepMilestonePoints[index]
            tiers.append(milestone)
        }
        return (points, tiers)
    }

    static func workoutPoints(
        durationSec: Int,
        zoneMinutes: HRZoneMinutes,
        profile: VitalityProfile,
        mascotId: String
    ) -> Int {
        let minutes = durationSec / 60
        guard minutes >= minWorkoutMinutes else { return 0 }

        var points = baseWorkoutPoints
        let extraMinutes = max(0, minutes - minWorkoutMinutes)
        points += (extraMinutes / 5) * pointsPerFiveExtraMinutes
        points += VitalityHRZones.zoneBonusPoints(zoneMinutes)

        let multiplier = MascotConstants.gameplay(mascotId).coinMultiplier
        return max(0, Int((Double(points) * multiplier).rounded()))
    }

    static func buildDailyRecord(
        date: String,
        steps: Int,
        sleepMinutes: Int = 0,
        workouts: [VitalityWorkout],
        profile: VitalityProfile,
        mascotId: String
    ) -> DailyVitalityRecord {
        let stepResult = stepPoints(for: steps)
        let sleepResult = sleepPoints(for: sleepMinutes)
        let maxHR = VitalityHRZones.maxHeartRate(sex: profile.sex, age: profile.age)

        var scoredWorkouts = workouts
        var workoutPointsTotal = 0
        for index in scoredWorkouts.indices {
            let zones = VitalityHRZones.resolvedZoneMinutes(
                stored: scoredWorkouts[index].zoneMinutes,
                averageHeartRate: scoredWorkouts[index].avgHeartRate,
                durationSec: scoredWorkouts[index].durationSec,
                maxHR: maxHR
            )
            let earned = workoutPoints(
                durationSec: scoredWorkouts[index].durationSec,
                zoneMinutes: zones,
                profile: profile,
                mascotId: mascotId
            )
            scoredWorkouts[index].zoneMinutes = zones
            scoredWorkouts[index].pointsEarned = earned
            workoutPointsTotal += earned
        }

        let total = stepResult.points + sleepResult.points + workoutPointsTotal
        return DailyVitalityRecord(
            id: date,
            date: date,
            steps: steps,
            stepPoints: stepResult.points,
            workoutPoints: workoutPointsTotal,
            sleepMinutes: sleepMinutes,
            sleepPoints: sleepResult.points,
            totalPoints: total,
            workouts: scoredWorkouts,
            stepTiersReached: stepResult.tiersReached
        )
    }

    static func mergeDailyRecords(
        _ existing: DailyVitalityRecord?,
        with incoming: DailyVitalityRecord,
        profile: VitalityProfile,
        mascotId: String
    ) -> DailyVitalityRecord {
        guard let existing else { return incoming }
        var workouts = existing.workouts
        let existingIds = Set(workouts.map(\.id))
        for workout in incoming.workouts where !existingIds.contains(workout.id) {
            workouts.append(workout)
        }
        let steps = max(existing.steps, incoming.steps)
        let sleepMinutes = max(existing.sleepMinutes, incoming.sleepMinutes)
        return buildDailyRecord(
            date: incoming.date,
            steps: steps,
            sleepMinutes: sleepMinutes,
            workouts: workouts,
            profile: profile,
            mascotId: mascotId
        )
    }

    /// Updates only `dateKey` when `steps` is higher than the stored count. Returns nil if nothing changed.
    static func applyingSteps(
        _ steps: Int,
        on dateKey: String,
        to records: [DailyVitalityRecord],
        profile: VitalityProfile,
        mascotId: String
    ) -> [DailyVitalityRecord]? {
        guard steps > 0 else { return nil }
        let existing = records.first { $0.date == dateKey }
        guard steps > (existing?.steps ?? 0) else { return nil }
        let incoming = buildDailyRecord(
            date: dateKey,
            steps: steps,
            sleepMinutes: existing?.sleepMinutes ?? 0,
            workouts: existing?.workouts ?? [],
            profile: profile,
            mascotId: mascotId
        )
        let merged = mergeDailyRecords(existing, with: incoming, profile: profile, mascotId: mascotId)
        var byDate = Dictionary(uniqueKeysWithValues: records.map { ($0.date, $0) })
        byDate[dateKey] = merged
        return byDate.values.sorted { $0.date < $1.date }
    }

    static func totalPoints(in records: [DailyVitalityRecord], monthKey: String? = nil) -> Int {
        filtered(records, monthKey: monthKey).reduce(0) { $0 + $1.totalPoints }
    }

    static func totalPoints(in records: [DailyVitalityRecord], weekKey: String) -> Int {
        records.filter { VitalityGoals.weekKey(for: $0.date) == weekKey }.reduce(0) { $0 + $1.totalPoints }
    }

    static func filtered(_ records: [DailyVitalityRecord], monthKey: String?) -> [DailyVitalityRecord] {
        guard let monthKey else { return records }
        return records.filter { $0.date.hasPrefix(monthKey) }
    }
}

enum TodayStepsStore {
    static func apply(_ steps: Int, to data: inout VitalityData) -> Bool {
        let dateKey = VitalityGoals.todayDateKey()
        let mascotId = MascotUnlock.resolveMascotId(
            profile: data.profile,
            dailyRecords: data.dailyRecords,
            goalState: data.goalState,
            monthlyChallengeRerolls: data.monthlyChallengeRerolls
        )
        guard let nextRecords = VitalityPoints.applyingSteps(
            steps,
            on: dateKey,
            to: data.dailyRecords,
            profile: data.profile,
            mascotId: mascotId
        ) else { return false }

        data.dailyRecords = nextRecords
        let intensity = MascotConstants.gameplay(mascotId).challengeIntensity
        VitalityGoals.ensureGoals(data: &data, intensity: intensity)
        VitalityGoals.recordMonthlyCompletionIfNeeded(
            data: &data,
            monthKey: VitalityGoals.getMonthKey()
        )
        _ = VitalityStreak.reconcile(goalState: &data.goalState, records: nextRecords)
        return true
    }
}
