import Foundation
import UserNotifications

enum SwimNotifications {
    static let daysBeforeMonthEndToRemind = 5

    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func refreshMonthlyGoalReminders(
        sessions: [SwimSession],
        profile: SwimProfile,
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

        let prefix = "monthly-goals-"
        let pending = await center.pendingNotificationRequests()
        for request in pending where request.identifier.hasPrefix(prefix) {
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
        profile: SwimProfile,
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
            id: "monthly-goals-\(monthKey)",
            title: t.t("notifications.monthlyGoalsTitle"),
            body: t.t("notifications.monthlyGoalsBody", params: [
                "count": "\(open.count)",
                "days": "\(daysLeft)",
                "goals": openSummary,
            ])
        )]
    }
}
