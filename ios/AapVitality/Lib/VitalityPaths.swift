import Foundation

enum VitalityPaths {
    struct PathDefinition: Equatable {
        var id: String
        var titleKey: String
        var medalIds: [String]
    }

    static let paths: [PathDefinition] = [
        PathDefinition(
            id: "steps_path",
            titleKey: "vitality.paths.steps",
            medalIds: ["five_k_steps", "ten_k_steps", "twenty_k_steps", "step_streak_7", "step_streak_14"]
        ),
        PathDefinition(
            id: "workout_path",
            titleKey: "vitality.paths.workouts",
            medalIds: ["first_workout", "ten_workouts", "thirty_workouts", "endurance_45", "zone_master"]
        ),
        PathDefinition(
            id: "goals_path",
            titleKey: "vitality.paths.goals",
            medalIds: ["weekly_goal_hit", "monthly_goal_hit", "yearly_halfway", "yearly_goal_hit", "early_finisher"]
        ),
        PathDefinition(
            id: "consistency_path",
            titleKey: "vitality.paths.consistency",
            medalIds: ["first_points", "ten_active_days", "fifty_active_days", "hat_trick", "week_warrior", "fortnight_flow"]
        ),
        PathDefinition(
            id: "recovery_path",
            titleKey: "vitality.paths.recovery",
            medalIds: ["sleep_7h", "sleep_8h", "sleep_streak_3", "comeback", "walk_and_work"]
        ),
    ]

    static func progress(for medals: [EvaluatedMedal]) -> [AchievementPathProgress] {
        let earnedIds = Set(medals.filter(\.earned).map(\.id))
        return paths.map { path in
            let completed = path.medalIds.filter { earnedIds.contains($0) }.count
            let next = path.medalIds.first { !earnedIds.contains($0) }
            let percent = path.medalIds.isEmpty
                ? 0
                : min(100, Int((Double(completed) / Double(path.medalIds.count) * 100).rounded()))
            return AchievementPathProgress(
                id: path.id,
                titleKey: path.titleKey,
                medalIds: path.medalIds,
                completedCount: completed,
                totalCount: path.medalIds.count,
                nextMedalId: next,
                progressPercent: percent
            )
        }
    }
}
