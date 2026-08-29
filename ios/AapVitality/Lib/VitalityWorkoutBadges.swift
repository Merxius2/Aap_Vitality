import Foundation

enum VitalityWorkoutBadges {
    static let trackedTypes = [
        "running", "walking", "cycling", "swimming", "yoga", "strength", "hiit", "hiking", "elliptical", "rowing"
    ]

    private static let tierTargets: [(tier: String, count: Int)] = [
        ("bronze", 5),
        ("silver", 15),
        ("gold", 30),
    ]

    static func typeCounts(from records: [DailyVitalityRecord]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for record in records {
            for workout in record.workouts where workout.durationSec >= VitalityPoints.minWorkoutMinutes * 60 {
                counts[workout.workoutType, default: 0] += 1
            }
        }
        return counts
    }

    static func earnedBadges(from records: [DailyVitalityRecord]) -> [WorkoutTypeBadge] {
        let counts = typeCounts(from: records)
        var badges: [WorkoutTypeBadge] = []
        for type in trackedTypes {
            let count = counts[type, default: 0]
            guard count > 0 else { continue }
            if let highest = tierTargets.last(where: { count >= $0.count }) {
                badges.append(WorkoutTypeBadge(
                    id: "\(type)_\(highest.tier)",
                    workoutType: type,
                    tier: highest.tier,
                    count: count,
                    target: highest.count
                ))
            } else {
                badges.append(WorkoutTypeBadge(
                    id: "\(type)_progress",
                    workoutType: type,
                    tier: "progress",
                    count: count,
                    target: tierTargets[0].count
                ))
            }
        }
        return badges.sorted { $0.count > $1.count }
    }

    static func dailyTypeBadges(for record: DailyVitalityRecord) -> [String] {
        Array(Set(record.workouts
            .filter { $0.durationSec >= VitalityPoints.minWorkoutMinutes * 60 }
            .map(\.workoutType)))
            .sorted()
    }
}
