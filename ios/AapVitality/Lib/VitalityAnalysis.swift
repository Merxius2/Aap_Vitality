import Foundation

enum VitalityAnalysis {
    static func buildProgressOverviewMessage(
        profile: VitalityProfile,
        records: [DailyVitalityRecord],
        goalSnapshot: VitalityGoalSnapshot,
        goalState: VitalityGoalState,
        t: TranslationService,
        mascotId: String
    ) -> String {
        let gameplay = MascotConstants.gameplay(mascotId)
        let displayName = profile.displayName(fallback: t.t("settings.defaultProfileName"))

        guard !records.isEmpty else {
            return t.t("progress.mascotEmpty", params: ["name": displayName])
        }

        var parts: [String] = []
        let today = records.max(by: { $0.date < $1.date })

        if let memoryWin = MascotMemory.headlineWin(
            records: records,
            goalState: goalState,
            mascotId: mascotId
        ) {
            parts.append(MascotMemory.message(for: memoryWin, t: t))
        }

        if let today {
            appendTodayHighlights(
                today: today,
                parts: &parts,
                mascotId: mascotId,
                t: t
            )
        }

        parts.append(t.t("progress.overviewMonthlyGoal", params: [
            "current": String(goalSnapshot.monthlyEarned),
            "target": String(goalSnapshot.monthlyTarget),
            "percent": String(goalSnapshot.monthlyPercent)
        ]))

        if mascotId == "fins", goalSnapshot.monthlyPercent < 100 {
            let stretch = Int((Double(goalSnapshot.monthlyTarget) * 1.15).rounded())
            parts.append(t.t("progress.overviewStretchTarget", params: [
                "target": String(stretch),
                "current": String(goalSnapshot.monthlyEarned)
            ]))
        }

        appendGoalProgressParts(
            goalSnapshot: goalSnapshot,
            gameplay: gameplay,
            displayName: displayName,
            mascotId: mascotId,
            parts: &parts,
            t: t
        )

        let message = parts.filter { !$0.isEmpty }.joined(separator: " ")
        return SwimAnalysis.wrapCoachMessage(mascotId: mascotId, profile: profile, t: t, message: message)
    }

    private static func appendTodayHighlights(
        today: DailyVitalityRecord,
        parts: inout [String],
        mascotId: String,
        t: TranslationService
    ) {
        parts.append(t.t("progress.overviewTodayPoints", params: [
            "points": String(today.totalPoints),
            "steps": String(today.steps)
        ]))

        if today.sleepPoints > 0 {
            parts.append(t.t("vitality.overview.sleepBonus", params: [
                "points": String(today.sleepPoints)
            ]))
        }

        if today.stepTiersReached.contains(10000) {
            parts.append(t.t("progress.overviewStep10k"))
        } else if today.stepTiersReached.contains(5000) {
            parts.append(t.t("progress.overviewStep5k"))
        } else if mascotId == "flip", today.steps >= 3_000 {
            parts.append(t.t("progress.overviewFlipMoving", params: [
                "steps": String(today.steps)
            ]))
        }

        if today.workoutPoints > 0 {
            parts.append(t.t("progress.overviewWorkoutPoints", params: [
                "points": String(today.workoutPoints)
            ]))
        }

        if mascotId == "flip", today.totalPoints >= 10, today.totalPoints < 40 {
            parts.append(t.t("progress.overviewFlipPoints", params: [
                "points": String(today.totalPoints)
            ]))
        }
    }

    private static func appendGoalProgressParts(
        goalSnapshot: VitalityGoalSnapshot,
        gameplay: MascotGameplay,
        displayName: String,
        mascotId: String,
        parts: inout [String],
        t: TranslationService
    ) {
        let monthlyCompleteThreshold = mascotId == "flip" ? 75 : 100
        let monthlyNearThreshold = mascotId == "flip" ? 50 : 75

        if goalSnapshot.monthlyPercent >= 100 {
            parts.append(t.t("progress.overviewMonthlyComplete"))
        } else if goalSnapshot.monthlyPercent >= monthlyCompleteThreshold {
            parts.append(t.t("progress.overviewMonthlyNear"))
        } else if goalSnapshot.monthlyPercent >= monthlyNearThreshold, mascotId == "flip" {
            parts.append(t.t("progress.overviewFlipMonthlyProgress", params: [
                "percent": String(goalSnapshot.monthlyPercent)
            ]))
        } else if !gameplay.positiveOnly, goalSnapshot.monthlyPercent < 25 {
            parts.append(t.t("progress.overviewMonthlyBehind", params: ["name": displayName]))
        }

        let weeklyThreshold = mascotId == "flip" ? 50 : 100
        if goalSnapshot.weeklyPercent >= 100 {
            parts.append(t.t("progress.overviewWeeklyComplete"))
        } else if mascotId == "flip", goalSnapshot.weeklyPercent >= weeklyThreshold {
            parts.append(t.t("progress.overviewFlipWeeklyProgress", params: [
                "percent": String(goalSnapshot.weeklyPercent)
            ]))
        }
    }

    static func buildDailyFeedback(
        record: DailyVitalityRecord,
        profile: VitalityProfile,
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
        } else if mascotId == "flip", record.steps >= 3_000 {
            badges.append(t.t("progress.overviewFlipMoving", params: [
                "steps": String(record.steps)
            ]))
        }

        if record.sleepMinutes >= 480 {
            badges.append(t.t("vitality.badges.sleep8h"))
        } else if record.sleepMinutes >= 420 {
            badges.append(t.t("vitality.badges.sleep7h"))
        }

        for workoutType in VitalityWorkoutBadges.dailyTypeBadges(for: record) {
            badges.append(t.t("vitality.badges.workoutType", params: [
                "type": t.t("history.workoutType.\(workoutType)")
            ]))
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

        if record.sleepPoints > 0 {
            insights.append(t.t("vitality.insights.sleepBonus", params: [
                "minutes": String(record.sleepMinutes),
                "points": String(record.sleepPoints)
            ]))
        }

        insights.append(t.t("vitality.insights.dailyTotal", params: ["points": String(record.totalPoints)]))

        let thresholds = coachThresholds(for: mascotId)
        let coachMessage: String
        if record.totalPoints >= thresholds.strong {
            coachMessage = t.t("vitality.coach.strongDay")
        } else if record.totalPoints >= thresholds.good {
            coachMessage = t.t("vitality.coach.goodDay")
        } else if record.totalPoints >= thresholds.light {
            coachMessage = t.t("vitality.coach.lightDay")
        } else {
            coachMessage = t.t("vitality.coach.restDay")
        }

        let happyThreshold = mascotId == "flip" ? 25 : 50
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
            mascotMood: record.totalPoints >= happyThreshold ? "happy" : "neutral"
        )
    }

    private static func coachThresholds(for mascotId: String) -> (strong: Int, good: Int, light: Int) {
        switch mascotId {
        case "flip":
            return (strong: 50, good: 25, light: 5)
        case "fins":
            return (strong: 100, good: 60, light: 20)
        default:
            return (strong: 80, good: 40, light: 1)
        }
    }
}
