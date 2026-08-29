import Foundation

enum VitalityLevels {
    struct LevelDefinition: Equatable {
        var level: Int
        var titleKey: String
        var minLifetimePoints: Int
    }

    static let definitions: [LevelDefinition] = [
        LevelDefinition(level: 1, titleKey: "vitality.levels.starter", minLifetimePoints: 0),
        LevelDefinition(level: 2, titleKey: "vitality.levels.mover", minLifetimePoints: 500),
        LevelDefinition(level: 3, titleKey: "vitality.levels.active", minLifetimePoints: 2_000),
        LevelDefinition(level: 4, titleKey: "vitality.levels.dedicated", minLifetimePoints: 5_000),
        LevelDefinition(level: 5, titleKey: "vitality.levels.champion", minLifetimePoints: 12_000),
        LevelDefinition(level: 6, titleKey: "vitality.levels.elite", minLifetimePoints: 25_000),
        LevelDefinition(level: 7, titleKey: "vitality.levels.legend", minLifetimePoints: 50_000),
    ]

    static func lifetimePoints(from records: [DailyVitalityRecord]) -> Int {
        records.reduce(0) { $0 + $1.totalPoints }
    }

    static func snapshot(records: [DailyVitalityRecord]) -> VitalityLevelSnapshot {
        let total = lifetimePoints(from: records)
        let current = currentLevel(for: total)
        let next = definitions.first { $0.level == current.level + 1 }
        let floor = current.minLifetimePoints
        let ceiling = next?.minLifetimePoints ?? (floor + 1)
        let intoLevel = total - floor
        let span = max(1, ceiling - floor)
        let percent = next == nil ? 100 : min(100, Int((Double(intoLevel) / Double(span) * 100).rounded()))

        return VitalityLevelSnapshot(
            level: current.level,
            titleKey: current.titleKey,
            lifetimePoints: total,
            pointsIntoLevel: intoLevel,
            pointsToNextLevel: max(0, ceiling - total),
            progressPercent: percent
        )
    }

    static func currentLevel(for lifetimePoints: Int) -> LevelDefinition {
        definitions.last { lifetimePoints >= $0.minLifetimePoints } ?? definitions[0]
    }
}
