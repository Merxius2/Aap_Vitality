import Foundation

enum VitalityPoints {
    static let stepMilestones = [5000, 10000, 20000]
    static let stepMilestonePoints = [10, 15, 25]
    static let minWorkoutMinutes = 30
    static let baseWorkoutPoints = 20
    static let pointsPerFiveExtraMinutes = 2

    static func stepPoints(for steps: Int) -> (points: Int, tiersReached: [Int]) {
        var points = 0
        var tiers: [Int] = []
        for (index, milestone) in stepMilestones.enumerated() where steps >= milestone {
            points += stepMilestonePoints[index]
            tiers.append(milestone)
        }
        return (points, tiers)
    }

    static func workoutPoints(
        durationSec: Int,
        zoneMinutes: HRZoneMinutes,
        profile: SwimProfile,
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
        workouts: [VitalityWorkout],
        profile: SwimProfile,
        mascotId: String
    ) -> DailyVitalityRecord {
        let stepResult = stepPoints(for: steps)
        let maxHR = VitalityHRZones.maxHeartRate(sex: profile.sex, age: profile.age)

        var scoredWorkouts = workouts
        var workoutPointsTotal = 0
        for index in scoredWorkouts.indices {
            let zones = scoredWorkouts[index].zoneMinutes
                ?? VitalityHRZones.zoneMinutes(
                    from: scoredWorkouts[index].avgHeartRate,
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

        let total = stepResult.points + workoutPointsTotal
        return DailyVitalityRecord(
            id: date,
            date: date,
            steps: steps,
            stepPoints: stepResult.points,
            workoutPoints: workoutPointsTotal,
            totalPoints: total,
            workouts: scoredWorkouts,
            stepTiersReached: stepResult.tiersReached
        )
    }

    static func mergeDailyRecords(
        _ existing: DailyVitalityRecord?,
        with incoming: DailyVitalityRecord,
        profile: SwimProfile,
        mascotId: String
    ) -> DailyVitalityRecord {
        guard let existing else { return incoming }
        var workouts = existing.workouts
        let existingIds = Set(workouts.map(\.id))
        for workout in incoming.workouts where !existingIds.contains(workout.id) {
            workouts.append(workout)
        }
        let steps = max(existing.steps, incoming.steps)
        return buildDailyRecord(
            date: incoming.date,
            steps: steps,
            workouts: workouts,
            profile: profile,
            mascotId: mascotId
        )
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
