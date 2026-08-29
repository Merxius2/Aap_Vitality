import Foundation
import SwiftUI

@MainActor
final class VitalityViewModel: ObservableObject {
    @Published private(set) var data: VitalityData = .empty
    @Published private(set) var cheats: SwimCheats = .empty
    @Published private(set) var isLoading = true
    @Published var pendingMedalCelebration: [EvaluatedMedal]?
    @Published var isSyncingHealthKit = false
    @Published var healthKitSyncMessage: String?
    @Published var lastHealthKitImportResult: HealthKitImportResult?

    private var saveTask: Task<Void, Never>?
    private var hasAttemptedHealthKitAutoSync = false
    private static let healthKitAutoSyncAtKey = "HEALTHKIT_AUTO_SYNC_AT"
    private var cachedEvaluatedMedals: [EvaluatedMedal]?
    private var cachedMonthlyChallengeHistory: [MonthlyChallengeState]?
    private var medalCacheMonthKey: String?
    private var cachedCurrentMonthlyChallenges: MonthlyChallengeState?
    private var progressCacheMonthKey: String?
    private var cachedProgressOverviewMessage: String?
    private var progressOverviewCacheKey: String?

    var sessions: [SwimSession] { data.sessions }
    var dailyRecords: [DailyVitalityRecord] { data.dailyRecords }
    var goalState: VitalityGoalState { data.goalState }
    var profile: VitalityProfile { data.profile }
    var monthlyChallengeRerolls: [String: MonthRerollEntry] { data.monthlyChallengeRerolls }

    var vitalityGoalSnapshot: VitalityGoalSnapshot {
        VitalityGoals.goalSnapshot(
            records: dailyRecords,
            profile: profile,
            goalState: goalState,
            intensity: MascotConstants.gameplay(mascotId).challengeIntensity
        )
    }

    var todayVitalityRecord: DailyVitalityRecord? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let today = formatter.string(from: Date())
        return dailyRecords.first { $0.date == today }
    }

    var mascotId: String {
        MascotUnlock.resolveMascotId(
            profile: profile,
            dailyRecords: dailyRecords,
            goalState: goalState,
            monthlyChallengeRerolls: monthlyChallengeRerolls
        )
    }

    var evaluatedMedals: [EvaluatedMedal] {
        let monthKey = SwimMonthlyChallenges.getMonthKey()
        if let cached = cachedEvaluatedMedals, medalCacheMonthKey == monthKey {
            return cached
        }
        let medals = SwimMedals.evaluateAllMedals(
            dailyRecords,
            profile: profile,
            goalState: goalState,
            allMedalsUnlocked: cheats.allMedalsUnlocked
        )
        cachedEvaluatedMedals = medals
        medalCacheMonthKey = monthKey
        return medals
    }

    var vitalityLevelSnapshot: VitalityLevelSnapshot {
        VitalityLevels.snapshot(records: dailyRecords)
    }

    var vitalityStreakSnapshot: VitalityStreakSnapshot {
        VitalityStreak.snapshot(goalState: goalState, records: dailyRecords)
    }

    var achievementPathProgress: [AchievementPathProgress] {
        VitalityPaths.progress(for: evaluatedMedals)
    }

    var workoutTypeBadges: [WorkoutTypeBadge] {
        VitalityWorkoutBadges.earnedBadges(from: dailyRecords)
    }

    var currentMonthlyChallenges: MonthlyChallengeState {
        ensureProgressSessionCache()
        return cachedCurrentMonthlyChallenges ?? MonthlyChallengeState(
            monthKey: SwimMonthlyChallenges.getMonthKey(),
            challenges: [],
            completedCount: 0,
            tier: nil,
            earnedAt: nil
        )
    }

    func progressOverviewMessage(t: TranslationService) -> String {
        ensureProgressSessionCache()
        let cacheKey = progressLocalizedCacheKey(language: currentLanguageCode())
        if let cached = cachedProgressOverviewMessage, progressOverviewCacheKey == cacheKey {
            return cached
        }
        let message = VitalityAnalysis.buildProgressOverviewMessage(
            profile: profile,
            records: dailyRecords,
            goalSnapshot: vitalityGoalSnapshot,
            t: t,
            mascotId: mascotId
        )
        cachedProgressOverviewMessage = message
        progressOverviewCacheKey = cacheKey
        return message
    }

    var monthlyChallengeHistory: [MonthlyChallengeState] {
        if let cached = cachedMonthlyChallengeHistory {
            return cached
        }
        let intensity = MascotConstants.gameplay(mascotId).challengeIntensity
        let months = Array(Set(dailyRecords.map { String($0.date.prefix(7)) })).sorted(by: >)
        let history = months.compactMap { monthKey -> MonthlyChallengeState? in
            let state = VitalityGoals.evaluatePointChallenges(
                records: dailyRecords,
                profile: profile,
                goalState: goalState,
                monthKey: monthKey,
                intensity: intensity
            )
            return state.tier == nil ? nil : state
        }
        cachedMonthlyChallengeHistory = history
        return history
    }


    init() {
        load()
    }

    func load() {
        data = SwimStorageService.load()
        cheats = SwimCheatsService.load()
        invalidateDerivedCaches()
        isLoading = false
    }

    func updateProfile(_ updates: (inout VitalityProfile) -> Void) {
        var next = data
        updates(&next.profile)
        if let ambient = next.profile.activeAmbient, !AmbientCatalog.isValid(ambient) {
            next.profile.activeAmbient = nil
        }
        if let wallpaper = next.profile.activeWallpaper, !WallpaperCatalog.isValid(wallpaper) {
            next.profile.activeWallpaper = nil
        }
        data = next
        invalidateDerivedCaches()
        persist(immediate: true)
    }

    func switchMascot(_ nextMascotId: String) -> Bool {
        let current = mascotId
        let result = MascotUnlock.canSwitchMascot(
            profile: profile,
            dailyRecords: dailyRecords,
            goalState: goalState,
            nextMascotId: nextMascotId,
            currentMascotId: current
        )
        guard result.allowed else { return false }
        let monthKey = SwimMonthlyChallenges.getMonthKey()
        updateProfile { profile in
            profile.mascotId = nextMascotId
            if nextMascotId != current {
                profile.mascotSwitchMonthKey = monthKey
            }
        }
        return true
    }

    func addSession(
        date: String,
        metrics: SwimMetrics,
        healthKitWorkoutUUID: String? = nil
    ) -> SwimSession {
        let entry = SwimSession(
            id: SwimStorageService.createSessionId(),
            createdAt: ISO8601DateFormatter().string(from: Date()),
            date: date,
            metrics: metrics,
            healthKitWorkoutUUID: healthKitWorkoutUUID
        )
        data.sessions.append(entry)
        data.sessions.sort { $0.date < $1.date }
        invalidateDerivedCaches()
        persist()
        return entry
    }

    func removeDailyRecord(date: String) {
        data.dailyRecords.removeAll { $0.date == date }
        invalidateDerivedCaches()
        persist()
    }

    func removeSession(id: String) {
        data.sessions.removeAll { $0.id == id }
        invalidateDerivedCaches()
        persist()
    }

    func updateSession(id: String, updates: (inout SwimSession) -> Void) {
        guard let index = data.sessions.firstIndex(where: { $0.id == id }) else { return }
        updates(&data.sessions[index])
        invalidateDerivedCaches()
        persist()
    }

    func replaceData(_ nextData: VitalityData) {
        data = SwimStorageService.normalize(nextData)
        invalidateDerivedCaches()
        persist(immediate: true)
    }

    func clearAll() {
        data = .empty
        cheats = .empty
        invalidateDerivedCaches()
        SwimStorageService.clear()
        SwimCheatsService.clear()
    }

    func resetAllData() {
        clearAll()
    }

    func exportDataString() async throws -> String {
        try await SwimImportExport.generateExportString(from: data)
    }

    func importDataString(_ exportString: String) async throws {
        let imported = try await SwimImportExport.parseImportString(exportString)
        replaceData(imported)
    }

    @discardableResult
    func rerollMonthlyChallenge(monthKey: String, tierIndex: Int) -> Bool {
        guard let next = SwimMonthlyChallenges.applyMonthlyChallengeReroll(
            data: data,
            monthKey: monthKey,
            tierIndex: tierIndex,
            mascotId: mascotId
        ) else {
            return false
        }
        data = next
        invalidateDerivedCaches()
        persist(immediate: true)
        return true
    }

    func updateCheats(_ updates: (inout SwimCheats) -> Void) {
        updates(&cheats)
        invalidateDerivedCaches()
        SwimCheatsService.save(cheats)
    }





    func clearMedalCelebration() {
        pendingMedalCelebration = nil
    }

    func queueNewMedals(recordsBefore: [DailyVitalityRecord], recordsAfter: [DailyVitalityRecord]) {
        let newlyEarned = SwimMedals.getNewlyEarnedMedals(
            recordsBefore: recordsBefore,
            recordsAfter: recordsAfter,
            profile: profile,
            goalState: goalState,
            allMedalsUnlocked: cheats.allMedalsUnlocked
        )
        guard !newlyEarned.isEmpty else { return }

        if var existing = pendingMedalCelebration {
            let existingIds = Set(existing.map(\.id))
            for medal in newlyEarned where !existingIds.contains(medal.id) {
                existing.append(medal)
            }
            pendingMedalCelebration = existing
        } else {
            pendingMedalCelebration = newlyEarned
        }
    }

    func syncHealthKitWorkouts(
        requestAuthorizationIfNeeded: Bool = false,
        maxImports: Int = 40,
        since: Date? = nil,
        lookbackMonths: Int = 24,
        enrichHeartRate: Bool = true
    ) async {
        await syncVitalityData(
            requestAuthorizationIfNeeded: requestAuthorizationIfNeeded,
            maxImports: maxImports,
            since: since,
            lookbackMonths: lookbackMonths,
            enrichHeartRate: enrichHeartRate
        )
    }

    func syncVitalityData(
        requestAuthorizationIfNeeded: Bool = false,
        maxImports: Int = 40,
        since: Date? = nil,
        lookbackMonths: Int = 24,
        enrichHeartRate: Bool = true
    ) async {
        let t = makeTranslations()
        guard HealthKitService.isAvailable else {
            healthKitSyncMessage = t.t("upload.healthUnavailable")
            return
        }

        isSyncingHealthKit = true
        healthKitSyncMessage = nil
        defer { isSyncingHealthKit = false }

        do {
            if requestAuthorizationIfNeeded || !HealthKitService.isAuthorizedForWorkouts {
                try await HealthKitService.requestAuthorization()
            }
            let syncSince = since ?? healthKitLookbackDate(months: lookbackMonths)
            let result = try await importVitalityData(
                maxImports: maxImports,
                since: syncSince,
                enrichHeartRate: enrichHeartRate
            )
            lastHealthKitImportResult = result
            if result.importedCount > 0 {
                if result.hasMoreAvailable {
                    healthKitSyncMessage = t.t(
                        "upload.healthImportedPartial",
                        params: ["count": "\(result.importedCount)"]
                    )
                } else {
                    healthKitSyncMessage = t.t(
                        "upload.healthImported",
                        params: ["count": "\(result.importedCount)"]
                    )
                }
            } else if result.totalFound == 0 {
                healthKitSyncMessage = t.t("upload.healthNoData")
            } else {
                healthKitSyncMessage = t.t("upload.healthAlreadySynced")
            }
        } catch {
            healthKitSyncMessage = error.localizedDescription
        }

        await refreshNotifications(
            dailyGoalNotificationsEnabled: UserDefaults.standard.string(
                forKey: UserPreferencesService.dailyGoalNotificationsKey
            ) != "false"
        )
    }

    func shouldPerformLaunchVitalitySync() async -> Bool {
        guard !hasAttemptedHealthKitAutoSync else { return false }
        guard await HealthKitService.isReadyForLaunchSync() else { return false }
        return !isWithinHealthKitAutoSyncThrottle()
    }

    @discardableResult
    func performLaunchVitalitySync() async -> Int {
        guard !hasAttemptedHealthKitAutoSync else { return 0 }
        guard await HealthKitService.isReadyForLaunchSync() else { return 0 }
        guard !isWithinHealthKitAutoSyncThrottle() else { return 0 }

        hasAttemptedHealthKitAutoSync = true

        await syncHealthKitWorkouts(
            requestAuthorizationIfNeeded: false,
            maxImports: 20,
            since: healthKitSyncSinceDate(),
            enrichHeartRate: false
        )
        UserDefaults.standard.set(Date(), forKey: Self.healthKitAutoSyncAtKey)
        return lastHealthKitImportResult?.importedCount ?? 0
    }



    func syncHealthKitWorkoutsIfAuthorized() async {
        _ = await performLaunchVitalitySync()
    }

    func refreshNotifications(dailyGoalNotificationsEnabled: Bool) async {
        let intensity = MascotConstants.gameplay(mascotId).challengeIntensity
        await SwimNotifications.refreshAllReminders(
            sessions: sessions,
            dailyRecords: dailyRecords,
            profile: profile,
            goalState: data.goalState,
            monthlyChallengeRerolls: monthlyChallengeRerolls,
            intensity: intensity,
            dailyGoalNotificationsEnabled: dailyGoalNotificationsEnabled,
            t: makeTranslations()
        )
    }

    func refreshLaunchNotifications(dailyGoalNotificationsEnabled: Bool = true) async {
        await refreshNotifications(dailyGoalNotificationsEnabled: dailyGoalNotificationsEnabled)
    }

    private func currentLanguageCode() -> String {
        if let data = UserDefaults.standard.data(forKey: UserPreferencesService.languageKey),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let language = json["language"] as? String {
            return language
        }
        return TranslationService.defaultLanguage
    }

    private func makeTranslations() -> TranslationService {
        let translations = TranslationService()
        translations.setLanguage(currentLanguageCode())
        return translations
    }

    private func importVitalityData(
        maxImports: Int,
        since: Date,
        enrichHeartRate: Bool = true
    ) async throws -> HealthKitImportResult {
        let existingWorkoutUUIDs = Set(
            dailyRecords.flatMap(\.workouts).compactMap(\.healthKitWorkoutUUID)
        )
        let recordsBefore = dailyRecords

        async let stepsTask = HealthKitService.fetchDailySteps(since: since)
        async let sleepTask = HealthKitService.fetchDailySleep(since: since)
        async let workoutsTask = HealthKitService.fetchNewVitalityWorkouts(
            excluding: existingWorkoutUUIDs,
            since: since,
            maxResults: maxImports,
            profile: profile,
            enrichHeartRate: enrichHeartRate
        )

        let stepsByDate = try await stepsTask
        let sleepByDate = try await sleepTask
        let fetchResult = try await workoutsTask

        var recordsByDate = Dictionary(uniqueKeysWithValues: dailyRecords.map { ($0.date, $0) })
        var importedCount = 0

        func upsertRecord(date: String, steps: Int, sleepMinutes: Int, workouts: [VitalityWorkout]) {
            let existing = recordsByDate[date]
            let record = VitalityPoints.buildDailyRecord(
                date: date,
                steps: steps,
                sleepMinutes: sleepMinutes,
                workouts: workouts,
                profile: profile,
                mascotId: mascotId
            )
            recordsByDate[date] = VitalityPoints.mergeDailyRecords(
                existing,
                with: record,
                profile: profile,
                mascotId: mascotId
            )
        }

        let allDates = Set(stepsByDate.keys).union(sleepByDate.keys).union(recordsByDate.keys)
        for date in allDates.sorted() {
            let existing = recordsByDate[date]
            let steps = stepsByDate[date] ?? existing?.steps ?? 0
            let sleepMinutes = sleepByDate[date] ?? existing?.sleepMinutes ?? 0
            let workouts = existing?.workouts ?? []
            let before = existing
            upsertRecord(date: date, steps: steps, sleepMinutes: sleepMinutes, workouts: workouts)
            let after = recordsByDate[date]
            if before == nil || before?.steps != steps || before?.sleepMinutes != sleepMinutes {
                importedCount += 1
            }
            _ = after
        }

        for workout in fetchResult.workouts {
            guard workout.durationSec >= 60 else { continue }
            let vitalityWorkout = VitalityWorkout(
                id: workout.id,
                date: workout.date,
                workoutType: workout.workoutType,
                durationSec: workout.durationSec,
                avgHeartRate: workout.avgHeartRate,
                zoneMinutes: workout.zoneMinutes,
                activeKcal: workout.activeKcal,
                healthKitWorkoutUUID: workout.id,
                pointsEarned: 0
            )
            let existing = recordsByDate[workout.date]
            var workouts = existing?.workouts ?? []
            if workouts.contains(where: { $0.healthKitWorkoutUUID == workout.id }) { continue }
            workouts.append(vitalityWorkout)
            let steps = existing?.steps ?? stepsByDate[workout.date] ?? 0
            let sleepMinutes = existing?.sleepMinutes ?? sleepByDate[workout.date] ?? 0
            upsertRecord(date: workout.date, steps: steps, sleepMinutes: sleepMinutes, workouts: workouts)
            importedCount += 1
        }

        let nextRecords = recordsByDate.values.sorted { $0.date < $1.date }
        if nextRecords != dailyRecords {
            data.dailyRecords = nextRecords
            _ = VitalityStreak.reconcile(goalState: &data.goalState, records: nextRecords)
            VitalityGoals.ensureGoals(
                data: &data,
                intensity: MascotConstants.gameplay(mascotId).challengeIntensity
            )
            VitalityGoals.recordMonthlyCompletionIfNeeded(
                data: &data,
                monthKey: VitalityGoals.getMonthKey()
            )
            invalidateDerivedCaches()
            persist(immediate: true)
            queueNewMedals(recordsBefore: recordsBefore, recordsAfter: nextRecords)
        }

        let hasMoreAvailable = fetchResult.workouts.count >= maxImports
            || fetchResult.queriedCount >= HealthKitService.queryLimit

        return HealthKitImportResult(
            importedCount: importedCount,
            skippedCount: 0,
            totalFound: fetchResult.queriedCount + stepsByDate.count,
            hasMoreAvailable: hasMoreAvailable,
            lastImportedSessionId: nil
        )
    }

    private func isWithinHealthKitAutoSyncThrottle() -> Bool {
        if let lastSync = UserDefaults.standard.object(forKey: Self.healthKitAutoSyncAtKey) as? Date,
           Date().timeIntervalSince(lastSync) < 3600 {
            return true
        }
        return false
    }

    private func healthKitLookbackDate(months: Int) -> Date {
        let calendar = Calendar.current
        let lookback = calendar.date(byAdding: .month, value: -months, to: Date()) ?? .distantPast
        return lookback
    }

    private func healthKitSyncSinceDate() -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if let lastDate = dailyRecords.map(\.date).max(),
           let date = formatter.date(from: lastDate) {
            return Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        }
        return healthKitLookbackDate(months: 3)
    }

    private func ensureProgressSessionCache() {
        let monthKey = SwimMonthlyChallenges.getMonthKey()
        if cachedCurrentMonthlyChallenges != nil, progressCacheMonthKey == monthKey {
            return
        }

        let intensity = MascotConstants.gameplay(mascotId).challengeIntensity
        cachedCurrentMonthlyChallenges = VitalityGoals.evaluatePointChallenges(
            records: dailyRecords,
            profile: profile,
            goalState: goalState,
            monthKey: monthKey,
            intensity: intensity
        )
        progressCacheMonthKey = monthKey
        invalidateProgressLocalizedCaches()
    }

    private func progressLocalizedCacheKey(language: String) -> String {
        let name = profile.name
        let monthKey = progressCacheMonthKey ?? SwimMonthlyChallenges.getMonthKey()
        let recordCount = dailyRecords.count
        return "\(language)|\(name)|\(monthKey)|\(recordCount)"
    }

    private func invalidateProgressLocalizedCaches() {
        cachedProgressOverviewMessage = nil
        progressOverviewCacheKey = nil
    }

    private func invalidateDerivedCaches() {
        cachedEvaluatedMedals = nil
        cachedMonthlyChallengeHistory = nil
        medalCacheMonthKey = nil
        cachedCurrentMonthlyChallenges = nil
        progressCacheMonthKey = nil
        invalidateProgressLocalizedCaches()
    }

    private func persist(immediate: Bool = false) {
        if immediate {
            SwimStorageService.save(data)
            return
        }
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            SwimStorageService.save(data)
        }
    }
}
