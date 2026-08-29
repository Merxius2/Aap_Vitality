import Foundation

enum SwimStorageService {
    static let storageKey = "AUDIT_SWIM_DATA"
    static var defaults: UserDefaults = .standard

    static func load() -> VitalityData {
        guard let raw = defaults.data(forKey: storageKey) else {
            return .empty
        }
        do {
            let parsed = try JSONDecoder().decode(VitalityData.self, from: raw)
            return migrate(parsed)
        } catch {
            return .empty
        }
    }

    static func save(_ data: VitalityData) {
        do {
            let encoded = try JSONEncoder().encode(data)
            defaults.set(encoded, forKey: storageKey)
        } catch {
            print("Failed to save swim data: \(error)")
        }
    }

    static func clear() {
        defaults.removeObject(forKey: storageKey)
    }

    static func createSessionId() -> String {
        UUID().uuidString
    }

    static func normalize(_ data: VitalityData) -> VitalityData {
        migrate(data)
    }

    private static func migrate(_ data: VitalityData) -> VitalityData {
        var next = data
        next.sessions = next.sessions.sorted { $0.date < $1.date }
        next.dailyRecords = next.dailyRecords.sorted { $0.date < $1.date }
        next.bodyMetricsEntries = next.bodyMetricsEntries.sorted { $0.date < $1.date }
        next.profile.activeAmbient = sanitizeAmbient(next.profile.activeAmbient)
        next.profile.activeWallpaper = sanitizeWallpaper(next.profile.activeWallpaper)
        next.monthlyChallengeRerolls = SwimMonthlyChallenges.normalizeMonthlyChallengeRerolls(
            next.monthlyChallengeRerolls
        )
        VitalityGoals.ensureGoals(data: &next)
        VitalityGoals.recordMonthlyCompletionIfNeeded(data: &next, monthKey: VitalityGoals.getMonthKey())
        _ = VitalityStreak.reconcile(goalState: &next.goalState, records: next.dailyRecords)
        return next
    }

    private static func sanitizeAmbient(_ activeAmbient: String?) -> String? {
        guard let activeAmbient, AmbientCatalog.isValid(activeAmbient) else { return nil }
        return activeAmbient
    }

    private static func sanitizeWallpaper(_ activeWallpaper: String?) -> String? {
        guard let activeWallpaper, WallpaperCatalog.isValid(activeWallpaper) else { return nil }
        return activeWallpaper
    }
}
