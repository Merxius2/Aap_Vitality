import Foundation
import SwiftUI
import PhotosUI

@MainActor
final class SwimViewModel: ObservableObject {
    @Published private(set) var data: SwimData = .empty
    @Published private(set) var cheats: SwimCheats = .empty
    @Published private(set) var isLoading = true
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var isProcessingOCR = false
    @Published var ocrErrorMessage: String?
    @Published var parsedResult: ParsedScreenshotResult?
    @Published var uploadDraft = UploadDraft.empty
    @Published var pendingMedalCelebration: [EvaluatedMedal]?
    @Published var duplicateSession: SwimSession?
    @Published var lastUploadFeedback: SessionFeedbackSummary?
    @Published var isEnhancingUploadFeedback = false
    @Published var isSyncingHealthKit = false
    @Published var healthKitSyncMessage: String?
    @Published var lastHealthKitImportResult: HealthKitImportResult?

    private var saveTask: Task<Void, Never>?
    private var hasAttemptedHealthKitAutoSync = false
    private static let healthKitAutoSyncAtKey = "HEALTHKIT_AUTO_SYNC_AT"
    private var cachedEvaluatedMedals: [EvaluatedMedal]?
    private var cachedMonthlyChallengeHistory: [MonthlyChallengeState]?
    private var medalCacheMonthKey: String?
    private var cachedProgressChartPoints: [ChartSessionPoint]?
    private var cachedProgressCombinedStats: CombinedStats?
    private var cachedProgressStatsSessionCount: Int?
    private var cachedProgressWeeklyVolume: [WeeklyVolumePoint]?
    private var cachedProgressPersonalRecords: PersonalRecords?
    private var cachedCurrentMonthlyChallenges: MonthlyChallengeState?
    private var progressCacheMonthKey: String?
    private var cachedProgressOverviewMessage: String?
    private var progressOverviewCacheKey: String?
    private var cachedLatestSessionFeedback: SessionFeedbackSummary?
    private var latestSessionFeedbackCacheKey: String?
    private var cachedProgressStrokeChartSlices: [StrokeChartSlice]?
    private var strokeChartCacheKey: String?

    var sessions: [SwimSession] { data.sessions }
    var dailyRecords: [DailyVitalityRecord] { data.dailyRecords }
    var goalState: VitalityGoalState { data.goalState }
    var profile: SwimProfile { data.profile }
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

    var progressChartPoints: [ChartSessionPoint] {
        ensureProgressSessionCache()
        return cachedProgressChartPoints ?? []
    }

    var progressCombinedStats: CombinedStats? {
        ensureProgressSessionCache()
        return cachedProgressCombinedStats
    }

    var progressStatsSessionCount: Int {
        ensureProgressSessionCache()
        return cachedProgressStatsSessionCount ?? 0
    }

    var progressWeeklyVolume: [WeeklyVolumePoint] {
        ensureProgressSessionCache()
        return cachedProgressWeeklyVolume ?? []
    }

    var progressPersonalRecords: PersonalRecords? {
        ensureProgressSessionCache()
        return cachedProgressPersonalRecords
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

    func latestSessionProgressFeedback(t: TranslationService) -> SessionFeedbackSummary? {
        guard let latest = sessions.last else { return nil }
        ensureProgressSessionCache()
        let cacheKey = progressLocalizedCacheKey(language: currentLanguageCode())
        if let cached = cachedLatestSessionFeedback, latestSessionFeedbackCacheKey == cacheKey {
            return cached
        }
        let feedback = SwimAnalysis.buildPersonalFeedback(
            session: latest,
            allSessions: sessions,
            profile: profile,
            t: t,
            monthlyChallengeRerolls: monthlyChallengeRerolls
        )
        cachedLatestSessionFeedback = feedback
        latestSessionFeedbackCacheKey = cacheKey
        return feedback
    }

    func progressStrokeChartSlices(t: TranslationService) -> [StrokeChartSlice] {
        ensureProgressSessionCache()
        let cacheKey = progressLocalizedCacheKey(language: currentLanguageCode())
        if let cached = cachedProgressStrokeChartSlices, strokeChartCacheKey == cacheKey {
            return cached
        }
        let slices = SwimAnalysis.strokeChartData(sessions.last, t: t)
        cachedProgressStrokeChartSlices = slices
        strokeChartCacheKey = cacheKey
        return slices
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

    func updateProfile(_ updates: (inout SwimProfile) -> Void) {
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

    func replaceData(_ nextData: SwimData) {
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

    func processSelectedPhoto() async {
        guard let selectedPhotoItem else { return }
        isProcessingOCR = true
        ocrErrorMessage = nil
        defer { isProcessingOCR = false }

        do {
            guard let photoData = try await selectedPhotoItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: photoData) else {
                ocrErrorMessage = "Could not load the selected photo."
                return
            }
            let result = try await OCRService.parseSwimScreenshot(from: image)
            parsedResult = result
            uploadDraft = UploadDraft.from(parsed: result.fields)
        } catch {
            ocrErrorMessage = error.localizedDescription
        }
    }

    func saveUploadDraft(ignoreDuplicate: Bool = false) -> Bool {
        if !ignoreDuplicate {
            let metrics = uploadDraft.toMetrics()
            let candidate = SwimSession(date: uploadDraft.resolvedDate, metrics: metrics)
            if let duplicate = SwimDuplicates.findDuplicateSession(sessions, candidate: candidate) {
                duplicateSession = duplicate
                return false
            }
        }

        guard prepareUploadSave() else { return false }

        let metrics = uploadDraft.toMetrics()
        let date = uploadDraft.resolvedDate

        let saved = addSession(date: date, metrics: metrics)

        lastUploadFeedback = SwimAnalysis.buildPersonalFeedback(
            session: saved,
            allSessions: sessions,
            profile: profile,
            t: makeTranslations()
        )
        isEnhancingUploadFeedback = !profile.aiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        Task { await enhanceUploadFeedback(for: saved) }

        parsedResult = nil
        selectedPhotoItem = nil
        duplicateSession = nil
        return true
    }

    func clearUploadDraft() {
        uploadDraft = .empty
        parsedResult = nil
        selectedPhotoItem = nil
        ocrErrorMessage = nil
        duplicateSession = nil
    }

    func clearUploadCelebrationState() {
        lastUploadFeedback = nil
        isEnhancingUploadFeedback = false
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

    func buildSessionFeedback(for session: SwimSession, t: TranslationService) -> SessionFeedbackSummary {
        SwimAnalysis.buildPersonalFeedback(
            session: session,
            allSessions: sessions,
            profile: profile,
            t: t,
            monthlyChallengeRerolls: monthlyChallengeRerolls
        )
    }

    func enhanceSessionFeedback(
        _ feedback: SessionFeedbackSummary,
        for session: SwimSession
    ) async -> SessionFeedbackSummary? {
        guard !profile.aiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        var updated = feedback
        let language = currentLanguageCode()
        do {
            let ai = try await AiCoachService.fetchFeedback(
                apiKey: profile.aiApiKey,
                language: language,
                profile: profile,
                session: session,
                sessions: sessions,
                localFeedback: feedback,
                mascotId: mascotId
            )
            updated.coachMessage = ai.coachMessage
            updated.motivation = ai.motivation
            updated.aiEnhanced = ai.aiEnhanced
            return updated
        } catch {
            return nil
        }
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

    private func enhanceUploadFeedback(for session: SwimSession) async {
        defer { isEnhancingUploadFeedback = false }
        guard !profile.aiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              var feedback = lastUploadFeedback else { return }
        let language = currentLanguageCode()
        do {
            let ai = try await AiCoachService.fetchFeedback(
                apiKey: profile.aiApiKey,
                language: language,
                profile: profile,
                session: session,
                sessions: sessions,
                localFeedback: feedback,
                mascotId: mascotId
            )
            feedback.coachMessage = ai.coachMessage
            feedback.motivation = ai.motivation
            feedback.aiEnhanced = ai.aiEnhanced
            lastUploadFeedback = feedback
        } catch {
            // Keep local feedback when AI is unavailable.
        }
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

    private func prepareUploadSave() -> Bool {
        let metrics = uploadDraft.toMetrics()
        let date = uploadDraft.resolvedDate
        let candidate = SwimSession(date: date, metrics: metrics)

        queueNewMedals(recordsBefore: dailyRecords, recordsAfter: dailyRecords)
        return true
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
        if cachedProgressChartPoints != nil, progressCacheMonthKey == monthKey {
            return
        }

        cachedProgressChartPoints = ChartMovingAverage.enrichChartSessions(
            SwimAnalysis.chartSessions(sessions)
        )
        cachedProgressCombinedStats = SwimAnalysis.combinedStats(sessions)
        cachedProgressStatsSessionCount = SwimAnalysis.statsSessions(sessions).count
        cachedProgressWeeklyVolume = ChartMovingAverage.enrichWeeklyVolume(
            SwimAnalysis.weeklyVolumeData(sessions)
        )
        cachedProgressPersonalRecords = SwimRecords.getPersonalRecords(sessions)
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
        let latestId = sessions.last?.id ?? ""
        let name = profile.name
        let monthKey = progressCacheMonthKey ?? SwimMonthlyChallenges.getMonthKey()
        return "\(language)|\(name)|\(latestId)|\(monthKey)"
    }

    private func invalidateProgressLocalizedCaches() {
        cachedProgressOverviewMessage = nil
        progressOverviewCacheKey = nil
        cachedLatestSessionFeedback = nil
        latestSessionFeedbackCacheKey = nil
        cachedProgressStrokeChartSlices = nil
        strokeChartCacheKey = nil
    }

    private func invalidateDerivedCaches() {
        cachedEvaluatedMedals = nil
        cachedMonthlyChallengeHistory = nil
        medalCacheMonthKey = nil
        cachedProgressChartPoints = nil
        cachedProgressCombinedStats = nil
        cachedProgressStatsSessionCount = nil
        cachedProgressWeeklyVolume = nil
        cachedProgressPersonalRecords = nil
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

struct UploadDraft: Equatable {
    var date: String
    var duration: String
    var distance: String
    var pace: String
    var activeKcal: String
    var totalKcal: String
    var avgHeartRate: String
    var laps: String
    var poolLength: String
    var goal: String
    var location: String
    var timeRange: String
    var strokes: StrokeDistances

    static let empty = UploadDraft(
        date: "", duration: "", distance: "", pace: "",
        activeKcal: "", totalKcal: "", avgHeartRate: "",
        laps: "", poolLength: "25", goal: "", location: "", timeRange: "",
        strokes: .empty
    )

    var resolvedDate: String {
        if !date.isEmpty { return date }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    static func from(parsed fields: ParsedScreenshotFields) -> UploadDraft {
        UploadDraft(
            date: fields.date ?? "",
            duration: SwimFormatters.formatDuration(fields.durationSec),
            distance: fields.distanceM.map(String.init) ?? "",
            pace: fields.paceSecPer100m.map { SwimFormatters.formatPace($0).replacingOccurrences(of: "/100m", with: "") } ?? "",
            activeKcal: fields.activeKcal.map(String.init) ?? "",
            totalKcal: fields.totalKcal.map(String.init) ?? "",
            avgHeartRate: fields.avgHeartRate.map(String.init) ?? "",
            laps: fields.laps.map(String.init) ?? "",
            poolLength: String(fields.poolLengthM),
            goal: fields.goalM.map(String.init) ?? "",
            location: fields.location,
            timeRange: fields.timeRange,
            strokes: fields.strokes
        )
    }

    func toMetrics() -> SwimMetrics {
        SwimMetrics(
            durationSec: SwimFormatters.parseDurationSec(duration),
            distanceM: SwimFormatters.parseDistanceM(distance),
            activeKcal: Int(activeKcal),
            totalKcal: Int(totalKcal),
            paceSecPer100m: SwimFormatters.parsePaceSecPer100m(pace),
            avgHeartRate: Int(avgHeartRate),
            laps: Int(laps),
            poolLengthM: Int(poolLength) ?? 25,
            goalM: SwimFormatters.parseDistanceM(goal),
            location: location,
            timeRange: timeRange,
            strokes: strokes
        )
    }
}

private extension Optional where Wrapped == Int {
    init?(_ string: String) {
        guard !string.isEmpty, let value = Int(string) else {
            self = nil
            return
        }
        self = value
    }
}
