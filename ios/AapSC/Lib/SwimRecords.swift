import Foundation

enum SwimRecords {
    static func getPersonalRecords(_ sessions: [SwimSession]) -> PersonalRecords? {
        let stats = SwimAnalysis.statsSessions(sessions)
        guard !stats.isEmpty else { return nil }

        return PersonalRecords(
            longestDistance: bestSession(stats, { Double($0.metrics.distanceM ?? 0) }, better: >),
            fastestPace: bestSession(stats, { Double($0.metrics.paceSecPer100m ?? 0) }, better: { $0 < $1 && $0 > 0 }),
            mostActiveCalories: bestSession(stats, { Double($0.metrics.activeKcal ?? 0) }, better: >),
            mostTotalCalories: bestSession(stats, { Double($0.metrics.totalKcal ?? 0) }, better: >),
            mostLaps: bestSession(stats, { Double($0.metrics.laps ?? 0) }, better: >),
            longestDuration: bestSession(stats, { Double($0.metrics.durationSec ?? 0) }, better: >),
            highestHeartRate: bestSession(stats, { Double($0.metrics.avgHeartRate ?? 0) }, better: >)
        )
    }

    private static func bestSession(
        _ sessions: [SwimSession],
        _ pickValue: (SwimSession) -> Double,
        better: (Double, Double) -> Bool
    ) -> PersonalRecord? {
        var best: PersonalRecord?
        for session in sessions {
            let value = pickValue(session)
            guard value.isFinite, value > 0 else { continue }
            if best == nil || better(value, best!.value) {
                best = PersonalRecord(value: value, sessionId: session.id, date: session.date)
            }
        }
        return best
    }
}
