import Foundation
import UserNotifications

enum SwimNotifications {
    static let daysBeforeMonthEndToRemind = 5
    static let dailyGoalReminderHour = 18
    static let dailyGoalPrefix = "daily-goal-"
    static let monthlyGoalPrefix = "monthly-goals-"
    static let lastDailyGoalCelebrationKey = "NOTIF_LAST_DAILY_GOAL_CELEBRATION"
    static let lastDailyGoalReminderSentKey = "NOTIF_LAST_DAILY_GOAL_REMINDER"

    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func refreshAllReminders(
        sessions: [SwimSession],
        dailyRecords: [DailyVitalityRecord],
        profile: VitalityProfile,
        goalState: VitalityGoalState,
        monthlyChallengeRerolls: [String: MonthRerollEntry],
        intensity: Double,
        dailyGoalNotificationsEnabled: Bool,
        t: TranslationService,
        now: Date = Date()
    ) async {
        await refreshMonthlyGoalReminders(
            sessions: sessions,
            profile: profile,
            monthlyChallengeRerolls: monthlyChallengeRerolls,
            t: t,
            now: now
        )
        await refreshDailyGoalNotifications(
            records: dailyRecords,
            profile: profile,
            goalState: goalState,
            intensity: intensity,
            enabled: dailyGoalNotificationsEnabled,
            t: t,
            now: now
        )
    }

    static func refreshMonthlyGoalReminders(
        sessions: [SwimSession],
        profile: VitalityProfile,
        monthlyChallengeRerolls: [String: MonthRerollEntry],
        t: TranslationService,
        now: Date = Date()
    ) async {
        await requestAuthorizationIfNeeded()
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else { return }

        let reminders = monthlyGoalReminders(
            sessions: sessions,
            profile: profile,
            monthlyChallengeRerolls: monthlyChallengeRerolls,
            t: t,
            now: now
        )

        let pending = await center.pendingNotificationRequests()
        for request in pending where request.identifier.hasPrefix(monthlyGoalPrefix) {
            center.removePendingNotificationRequests(withIdentifiers: [request.identifier])
        }

        guard let reminder = reminders.first else { return }

        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default

        var dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour], from: now)
        dateComponents.hour = max((dateComponents.hour ?? 9), 9)

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: reminder.id,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    static func refreshDailyGoalNotifications(
        records: [DailyVitalityRecord],
        profile: VitalityProfile,
        goalState: VitalityGoalState,
        intensity: Double,
        enabled: Bool,
        t: TranslationService,
        now: Date = Date()
    ) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let dailyIds = pending.filter { $0.identifier.hasPrefix(dailyGoalPrefix) }.map(\.identifier)
        if !dailyIds.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: dailyIds)
        }

        guard enabled else { return }

        await requestAuthorizationIfNeeded()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else { return }

        let todayKey = VitalityGoals.todayDateKey(now)
        let snapshot = VitalityGoals.goalSnapshot(
            records: records,
            profile: profile,
            goalState: goalState,
            intensity: intensity
        )
        let dailyTarget = VitalityGoals.computeDailyTarget(
            weeklyTarget: snapshot.weeklyTarget,
            profile: profile,
            intensity: intensity
        )
        let todayPoints = VitalityGoals.todayPoints(records: records, dateKey: todayKey)

        if todayPoints >= dailyTarget {
            await scheduleDailyGoalCelebration(
                center: center,
                todayKey: todayKey,
                todayPoints: todayPoints,
                dailyTarget: dailyTarget,
                t: t
            )
            return
        }

        await scheduleDailyGoalReminder(
            center: center,
            todayKey: todayKey,
            todayPoints: todayPoints,
            dailyTarget: dailyTarget,
            t: t,
            now: now
        )
    }

    static func dailyGoalStatus(
        records: [DailyVitalityRecord],
        profile: VitalityProfile,
        goalState: VitalityGoalState,
        intensity: Double,
        dateKey: String = VitalityGoals.todayDateKey()
    ) -> (target: Int, earned: Int, remaining: Int, met: Bool) {
        let snapshot = VitalityGoals.goalSnapshot(
            records: records,
            profile: profile,
            goalState: goalState,
            intensity: intensity
        )
        let target = VitalityGoals.computeDailyTarget(
            weeklyTarget: snapshot.weeklyTarget,
            profile: profile,
            intensity: intensity
        )
        let earned = VitalityGoals.todayPoints(records: records, dateKey: dateKey)
        let remaining = max(0, target - earned)
        return (target, earned, remaining, earned >= target)
    }

    private static func scheduleDailyGoalCelebration(
        center: UNUserNotificationCenter,
        todayKey: String,
        todayPoints: Int,
        dailyTarget: Int,
        t: TranslationService
    ) async {
        let lastCelebration = UserDefaults.standard.string(forKey: lastDailyGoalCelebrationKey)
        guard lastCelebration != todayKey else { return }

        let content = UNMutableNotificationContent()
        content.title = t.t("notifications.dailyGoalReachedTitle")
        content.body = t.t("notifications.dailyGoalReachedBody", params: [
            "points": "\(todayPoints)",
            "target": "\(dailyTarget)",
        ])
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(dailyGoalPrefix)celebration-\(todayKey)",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
        UserDefaults.standard.set(todayKey, forKey: lastDailyGoalCelebrationKey)
    }

    private static func scheduleDailyGoalReminder(
        center: UNUserNotificationCenter,
        todayKey: String,
        todayPoints: Int,
        dailyTarget: Int,
        t: TranslationService,
        now: Date
    ) async {
        let remaining = max(0, dailyTarget - todayPoints)
        let content = UNMutableNotificationContent()
        content.title = t.t("notifications.dailyGoalReminderTitle")
        content.body = t.t("notifications.dailyGoalReminderBody", params: [
            "current": "\(todayPoints)",
            "target": "\(dailyTarget)",
            "remaining": "\(remaining)",
        ])
        content.sound = .default

        let calendar = Calendar.current
        var reminderComponents = calendar.dateComponents([.year, .month, .day], from: now)
        reminderComponents.hour = dailyGoalReminderHour
        reminderComponents.minute = 0
        let reminderDate = calendar.date(from: reminderComponents) ?? now

        if now < reminderDate {
            let trigger = UNCalendarNotificationTrigger(dateMatching: reminderComponents, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(dailyGoalPrefix)reminder-\(todayKey)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
            return
        }

        let lastReminder = UserDefaults.standard.string(forKey: lastDailyGoalReminderSentKey)
        guard lastReminder != todayKey else { return }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(dailyGoalPrefix)reminder-\(todayKey)",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
        UserDefaults.standard.set(todayKey, forKey: lastDailyGoalReminderSentKey)
    }

    static func daysRemainingInMonth(_ date: Date = Date()) -> Int {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let day = calendar.dateComponents([.day], from: date).day else {
            return 0
        }
        return max(0, range.count - day)
    }

    static func isNearMonthEnd(_ date: Date = Date()) -> Bool {
        daysRemainingInMonth(date) <= daysBeforeMonthEndToRemind
    }

    struct ReminderPayload: Equatable {
        var id: String
        var title: String
        var body: String
    }

    static func monthlyGoalReminders(
        sessions: [SwimSession],
        profile: VitalityProfile,
        monthlyChallengeRerolls: [String: MonthRerollEntry],
        t: TranslationService,
        now: Date = Date()
    ) -> [ReminderPayload] {
        guard isNearMonthEnd(now) else { return [] }

        let monthKey = SwimMonthlyChallenges.getMonthKey(now)
        let mascotId = MascotUnlock.resolveMascotId(
            profile: profile,
            sessions: sessions,
            monthlyChallengeRerolls: monthlyChallengeRerolls
        )
        let intensity = MascotConstants.gameplay(mascotId).challengeIntensity
        let state = SwimMonthlyChallenges.evaluateMonthlyChallenges(
            sessions: sessions,
            monthKey: monthKey,
            rerolls: monthlyChallengeRerolls,
            intensity: intensity
        )
        let open = state.challenges.filter { !$0.completed }
        guard !open.isEmpty, state.completedCount < 3 else { return [] }

        let daysLeft = daysRemainingInMonth(now)
        let openSummary = open.prefix(2).map {
            SwimMonthlyChallengeFormatters.formatChallengeTarget($0.type, $0.target, t: t)
        }.joined(separator: ", ")

        return [ReminderPayload(
            id: "\(monthlyGoalPrefix)\(monthKey)",
            title: t.t("notifications.monthlyGoalsTitle"),
            body: t.t("notifications.monthlyGoalsBody", params: [
                "count": "\(open.count)",
                "days": "\(daysLeft)",
                "goals": openSummary,
            ])
        )]
    }
}
