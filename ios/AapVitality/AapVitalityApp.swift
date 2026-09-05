import SwiftUI
import BackgroundTasks
import UIKit

@main
struct AapVitalityApp: App {
    @StateObject private var viewModel: VitalityViewModel
    @StateObject private var preferences = UserPreferencesService()

    init() {
        BackgroundTodayStepsSync.register()
        let viewModel = VitalityViewModel()
        _viewModel = StateObject(wrappedValue: viewModel)
        BackgroundTodayStepsSync.bind(viewModel)
        BackgroundTodayStepsSync.schedule()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(viewModel)
                .environmentObject(preferences)
        }
    }
}

private struct AppRootView: View {
    @EnvironmentObject private var viewModel: VitalityViewModel
    @EnvironmentObject private var preferences: UserPreferencesService
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.scenePhase) private var scenePhase

    @State private var showLaunchSync = false
    @State private var showMedalCelebration = false

    private var canShowMedalCelebration: Bool {
        showMedalCelebration
            && !showLaunchSync
            && viewModel.pendingMedalCelebration != nil
    }

    private var appIsDark: Bool {
        preferences.isDarkModeActive(systemColorScheme: systemColorScheme)
    }

    private var animationsPaused: Bool {
        scenePhase != .active
    }

    private var ambientBackgroundVisible: Bool {
        BackdropState.isCustomVisible(
            activeWallpaper: viewModel.profile.activeWallpaper,
            activeAmbient: viewModel.profile.activeAmbient
        )
    }

    var body: some View {
        ContentView()
            .environment(\.t, preferences.translations)
            .environment(\.themeColors, preferences.themeColors)
            .environment(\.appIsDark, appIsDark)
            .environment(\.ambientBackgroundVisible, ambientBackgroundVisible)
            .environment(\.appAnimationsPaused, animationsPaused)
            .environment(\.themeTypographyCode, preferences.themeCode)
            .tint(preferences.themeColors.displayPrimary)
            .preferredColorScheme(preferences.colorScheme)
            .themedBodyFont()
        .sheet(isPresented: $showLaunchSync) {
            SearchingNewSessionsSheet()
                .environmentObject(preferences)
                .preferredColorScheme(preferences.colorScheme)
        }
        .sheet(isPresented: Binding(
            get: { canShowMedalCelebration },
            set: { isPresented in
                if !isPresented {
                    showMedalCelebration = false
                    viewModel.clearMedalCelebration()
                }
            }
        )) {
            if let medals = viewModel.pendingMedalCelebration {
                MedalCelebrationSheet(medals: medals)
                    .environmentObject(preferences)
                    .preferredColorScheme(preferences.colorScheme)
            }
        }
        .onChange(of: viewModel.pendingMedalCelebration) { _, medals in
            if let medals, !medals.isEmpty {
                showMedalCelebration = true
            }
        }
        .onChange(of: showLaunchSync) { _, isShowing in
            if !isShowing, viewModel.pendingMedalCelebration != nil {
                showMedalCelebration = true
            }
        }
        .task(priority: .utility) {
            try? await Task.sleep(for: .milliseconds(300))
            await performLaunchVitalitySyncIfNeeded()
            await viewModel.refreshNotificationsAfterTodaySync(
                dailyGoalNotificationsEnabled: preferences.dailyGoalNotificationsEnabled
            )
            viewModel.startTodayStepsSync()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await viewModel.refreshNotificationsAfterTodaySync(
                        dailyGoalNotificationsEnabled: preferences.dailyGoalNotificationsEnabled
                    )
                    viewModel.startTodayStepsSync()
                }
            } else {
                viewModel.stopTodayStepsSync()
                BackgroundTodayStepsSync.syncBeforeBackgrounding()
            }
        }
        .onChange(of: preferences.dailyGoalNotificationsEnabled) { _, enabled in
            Task {
                await viewModel.refreshNotifications(dailyGoalNotificationsEnabled: enabled)
            }
        }
        .onAppear {
            ThemeTypography.applyUIKitAppearance(themeCode: preferences.themeCode)
        }
        .onChange(of: preferences.themeCode) { _, themeCode in
            ThemeTypography.applyUIKitAppearance(themeCode: themeCode)
        }
    }

    @MainActor
    private func performLaunchVitalitySyncIfNeeded() async {
        guard await viewModel.shouldPerformLaunchVitalitySync() else { return }

        showLaunchSync = true
        async let importedCount = viewModel.performLaunchVitalitySync()
        try? await Task.sleep(for: .milliseconds(900))
        _ = await importedCount
        showLaunchSync = false
    }
}

enum BackgroundTodayStepsSync {
    enum Kind: Equatable {
        case steps
        case stepsAndWorkouts
        case fullDay
    }

    static let taskIdentifier = "com.aapft.vitality.refresh-today-steps"
    static let interval: TimeInterval = 30 * 60
    static let workoutInterval: TimeInterval = 60 * 60
    static let reminderLeadTime: TimeInterval = 15 * 60
    static let endOfDayHour = 23
    static let endOfDayMinute = 30
    static let lastWorkoutSyncAtKey = "BG_LAST_WORKOUT_SYNC_AT"
    static let lastFullDaySyncDateKey = "BG_LAST_FULL_DAY_SYNC_DATE"

    nonisolated(unsafe) private static weak var viewModel: VitalityViewModel?

    static func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(refreshTask)
        }
    }

    static func bind(_ viewModel: VitalityViewModel) {
        self.viewModel = viewModel
    }

    static func schedule(now: Date = Date()) {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = nextEarliestBeginDate(now: now)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func nextEarliestBeginDate(
        now: Date = Date(),
        reminderHour: Int = SwimNotifications.dailyGoalReminderHour,
        interval: TimeInterval = interval,
        leadTime: TimeInterval = reminderLeadTime,
        endOfDayHour: Int = endOfDayHour,
        endOfDayMinute: Int = endOfDayMinute,
        lastFullDaySyncDateKey: String? = recordedLastFullDaySyncDateKey()
    ) -> Date {
        let calendar = Calendar.current
        let periodic = now.addingTimeInterval(interval)
        guard let reminder = calendar.date(
            bySettingHour: reminderHour,
            minute: 0,
            second: 0,
            of: now
        ), let endOfDay = calendar.date(
            bySettingHour: endOfDayHour,
            minute: endOfDayMinute,
            second: 0,
            of: now
        ) else {
            return periodic
        }

        let reminderLead = reminder.addingTimeInterval(-leadTime)
        if now >= reminderLead && now < reminder {
            return now.addingTimeInterval(60)
        }
        if now >= endOfDay {
            if lastFullDaySyncDateKey != VitalityGoals.todayDateKey(now) {
                return now.addingTimeInterval(60)
            }
            let tomorrowEnd = calendar.date(byAdding: .day, value: 1, to: endOfDay) ?? periodic
            return min(periodic, tomorrowEnd)
        }

        var candidates = [periodic]
        if now < reminderLead {
            candidates.append(reminderLead)
        }
        candidates.append(endOfDay)
        return candidates.min() ?? periodic
    }

    static func syncKind(
        now: Date = Date(),
        lastWorkoutSyncAt: Date? = recordedLastWorkoutSyncAt(),
        lastFullDaySyncDateKey: String? = recordedLastFullDaySyncDateKey(),
        endOfDayHour: Int = endOfDayHour,
        endOfDayMinute: Int = endOfDayMinute,
        workoutInterval: TimeInterval = workoutInterval
    ) -> Kind {
        let todayKey = VitalityGoals.todayDateKey(now)
        if isInEndOfDayWindow(now: now, hour: endOfDayHour, minute: endOfDayMinute),
           lastFullDaySyncDateKey != todayKey {
            return .fullDay
        }
        if shouldIncludeWorkouts(now: now, lastWorkoutSyncAt: lastWorkoutSyncAt, interval: workoutInterval) {
            return .stepsAndWorkouts
        }
        return .steps
    }

    static func isInEndOfDayWindow(
        now: Date,
        hour: Int = endOfDayHour,
        minute: Int = endOfDayMinute
    ) -> Bool {
        let calendar = Calendar.current
        guard let endOfDay = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) else {
            return false
        }
        return now >= endOfDay
    }

    static func shouldIncludeWorkouts(
        now: Date,
        lastWorkoutSyncAt: Date?,
        interval: TimeInterval = workoutInterval
    ) -> Bool {
        guard let lastWorkoutSyncAt else { return true }
        return now.timeIntervalSince(lastWorkoutSyncAt) >= interval
    }

    static func recordedLastWorkoutSyncAt() -> Date? {
        UserDefaults.standard.object(forKey: lastWorkoutSyncAtKey) as? Date
    }

    static func recordedLastFullDaySyncDateKey() -> String? {
        UserDefaults.standard.string(forKey: lastFullDaySyncDateKey)
    }

    static func handle(_ task: BGAppRefreshTask) {
        let work = Task {
            let success = await performSync()
            schedule()
            task.setTaskCompleted(success: success)
        }
        task.expirationHandler = {
            work.cancel()
            schedule()
            task.setTaskCompleted(success: false)
        }
    }

    @discardableResult
    static func performSync() async -> Bool {
        guard HealthKitService.isAvailable else { return false }
        guard await HealthKitService.isReadyForLaunchSync() else { return false }

        let now = Date()
        let kind = syncKind(now: now)
        var completedKind = kind
        var success = false
        if let viewModel {
            success = await viewModel.syncTodayIfAuthorized(scope: kind, enrichHeartRate: false)
            if !success {
                success = await syncAndApplySteps(using: viewModel)
                if success { completedKind = .steps }
            }
            if success {
                markSuccessfulSync(completedKind, at: now)
            }
            await viewModel.refreshNotifications(
                dailyGoalNotificationsEnabled: UserPreferencesService.areDailyGoalNotificationsEnabled
            )
            return success
        }

        success = await syncAndApplySteps(using: nil)
        if success {
            markSuccessfulSync(.steps, at: now)
        }
        return success
    }

    static func markSuccessfulSync(_ kind: Kind, at now: Date = Date()) {
        if kind == .stepsAndWorkouts || kind == .fullDay {
            UserDefaults.standard.set(now, forKey: lastWorkoutSyncAtKey)
        }
        if kind == .fullDay {
            UserDefaults.standard.set(VitalityGoals.todayDateKey(now), forKey: lastFullDaySyncDateKey)
        }
    }

    private static func syncAndApplySteps(using viewModel: VitalityViewModel?) async -> Bool {
        do {
            let steps = try await HealthKitService.fetchTodaySteps()
            if let viewModel {
                await viewModel.applyTodaySteps(steps)
            } else {
                await apply(steps)
            }
            return true
        } catch {
            return false
        }
    }

    @MainActor
    static func syncBeforeBackgrounding() {
        schedule()
        var taskId = UIBackgroundTaskIdentifier.invalid
        taskId = UIApplication.shared.beginBackgroundTask(withName: "today-vitality-sync") {
            UIApplication.shared.endBackgroundTask(taskId)
            taskId = .invalid
        }
        Task {
            _ = await performSync()
            if taskId != .invalid {
                UIApplication.shared.endBackgroundTask(taskId)
            }
        }
    }

    @MainActor
    private static func apply(_ steps: Int) {
        if let viewModel {
            viewModel.applyTodaySteps(steps)
            return
        }
        var data = SwimStorageService.load()
        let pointsBefore = VitalityGoals.todayPoints(records: data.dailyRecords)
        guard TodayStepsStore.apply(steps, to: &data) else { return }
        SwimStorageService.save(data)
        let pointsAfter = VitalityGoals.todayPoints(records: data.dailyRecords)
        Task {
            let translations = TranslationService()
            if let languageData = UserDefaults.standard.data(forKey: UserPreferencesService.languageKey),
               let json = try? JSONSerialization.jsonObject(with: languageData) as? [String: Any],
               let language = json["language"] as? String {
                translations.setLanguage(language)
            }
            await SwimNotifications.notifyPointsEarnedIfNeeded(
                previousPoints: pointsBefore,
                currentPoints: pointsAfter,
                enabled: UserPreferencesService.arePointsEarnedNotificationsEnabled,
                t: translations
            )
        }
    }
}
