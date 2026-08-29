import Foundation

enum VitalityAnalysis {
    static func buildProgressOverviewMessage(
        profile: SwimProfile,
        records: [DailyVitalityRecord],
        goalSnapshot: VitalityGoalSnapshot,
        t: TranslationService,
        mascotId: String
    ) -> String {
        let gameplay = MascotConstants.gameplay(mascotId)
        let name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = name.isEmpty ? MascotConstants.displayName(mascotId, t: t) : name

        guard !records.isEmpty else {
            return t.t("progress.mascotEmpty", params: ["name": displayName])
        }

        var parts: [String] = []
        let today = records.max(by: { $0.date < $1.date })

        if let today {
            parts.append(t.t("progress.overviewTodayPoints", params: [
                "points": String(today.totalPoints),
                "steps": String(today.steps)
            ]))
            if today.stepTiersReached.contains(10000) {
                parts.append(t.t("progress.overviewStep10k"))
            } else if today.stepTiersReached.contains(5000) {
                parts.append(t.t("progress.overviewStep5k"))
            }
            if today.workoutPoints > 0 {
                parts.append(t.t("progress.overviewWorkoutPoints", params: [
                    "points": String(today.workoutPoints)
                ]))
            }
        }

        parts.append(t.t("progress.overviewMonthlyGoal", params: [
            "current": String(goalSnapshot.monthlyEarned),
            "target": String(goalSnapshot.monthlyTarget),
            "percent": String(goalSnapshot.monthlyPercent)
        ]))

        if goalSnapshot.monthlyPercent >= 100 {
            parts.append(t.t("progress.overviewMonthlyComplete"))
        } else if goalSnapshot.monthlyPercent >= 75 {
            parts.append(t.t("progress.overviewMonthlyNear"))
        } else if !gameplay.positiveOnly && goalSnapshot.monthlyPercent < 25 {
            parts.append(t.t("progress.overviewMonthlyBehind", params: ["name": displayName]))
        }

        if goalSnapshot.weeklyPercent >= 100 {
            parts.append(t.t("progress.overviewWeeklyComplete"))
        }

        let message = parts.filter { !$0.isEmpty }.joined(separator: " ")
        return SwimAnalysis.wrapCoachMessage(mascotId: mascotId, profile: profile, t: t, message: message)
    }

    static func buildDailyFeedback(
        record: DailyVitalityRecord,
        profile: SwimProfile,
        t: TranslationService,
        mascotId: String
    ) -> SessionFeedbackSummary {
        var insights: [String] = []
        var badges: [String] = []

        if record.stepTiersReached.contains(20000) {
            badges.append(t.t("vitality.badges.step20k"))
        } else if record.stepTiersReached.contains(10000) {
            badges.append(t.t("vitality.badges.step10k"))
        } else if record.stepTiersReached.contains(5000) {
            badges.append(t.t("vitality.badges.step5k"))
        }

        let qualifyingWorkouts = record.workouts.filter { $0.durationSec >= VitalityPoints.minWorkoutMinutes * 60 }
        if !qualifyingWorkouts.isEmpty {
            badges.append(t.t("vitality.badges.workoutLogged"))
            let zoneTotal = qualifyingWorkouts.compactMap(\.zoneMinutes).reduce(0) { $0 + $1.zone4 + $1.zone5 }
            if zoneTotal >= 10 {
                insights.append(t.t("vitality.insights.highIntensity", params: ["minutes": String(zoneTotal)]))
            }
        } else if !record.workouts.isEmpty {
            insights.append(t.t("vitality.insights.workoutTooShort"))
        }

        insights.append(t.t("vitality.insights.dailyTotal", params: ["points": String(record.totalPoints)]))

        let coachMessage: String
        if record.totalPoints >= 80 {
            coachMessage = t.t("vitality.coach.strongDay")
        } else if record.totalPoints >= 40 {
            coachMessage = t.t("vitality.coach.goodDay")
        } else if record.totalPoints > 0 {
            coachMessage = t.t("vitality.coach.lightDay")
        } else {
            coachMessage = t.t("vitality.coach.restDay")
        }

        return SessionFeedbackSummary(
            insights: insights,
            badges: badges,
            coachMessage: SwimAnalysis.wrapCoachMessage(mascotId: mascotId, profile: profile, t: t, message: coachMessage),
            motivation: t.t("vitality.motivation.keepGoing"),
            benchmarkLevel: .unknown,
            highlights: [
                FeedbackHighlight(label: t.t("vitality.highlight.steps"), value: String(record.steps)),
                FeedbackHighlight(label: t.t("vitality.highlight.points"), value: String(record.totalPoints))
            ],
            tip: t.t("vitality.tip.daily"),
            mascotMood: record.totalPoints >= 50 ? "happy" : "neutral"
        )
    }
}
