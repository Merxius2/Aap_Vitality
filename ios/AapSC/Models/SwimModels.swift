import Foundation

struct StrokeDistances: Codable, Equatable {
    var mixedM: Int?
    var breaststrokeM: Int?
    var freestyleM: Int?
    var backstrokeM: Int?
    var butterflyM: Int?

    static let empty = StrokeDistances(
        mixedM: nil,
        breaststrokeM: nil,
        freestyleM: nil,
        backstrokeM: nil,
        butterflyM: nil
    )
}

struct SwimMetrics: Codable, Equatable {
    var durationSec: Int?
    var distanceM: Int?
    var activeKcal: Int?
    var totalKcal: Int?
    var paceSecPer100m: Int?
    var avgHeartRate: Int?
    var laps: Int?
    var poolLengthM: Int
    var goalM: Int?
    var location: String
    var timeRange: String
    var strokes: StrokeDistances

    static let empty = SwimMetrics(
        durationSec: nil,
        distanceM: nil,
        activeKcal: nil,
        totalKcal: nil,
        paceSecPer100m: nil,
        avgHeartRate: nil,
        laps: nil,
        poolLengthM: 25,
        goalM: nil,
        location: "",
        timeRange: "",
        strokes: .empty
    )
}

struct SwimSession: Codable, Identifiable, Equatable {
    var id: String
    var createdAt: String?
    var date: String
    var metrics: SwimMetrics
    var excludeFromStats: Bool
    var healthKitWorkoutUUID: String?

    init(
        id: String = UUID().uuidString,
        createdAt: String? = nil,
        date: String,
        metrics: SwimMetrics,
        excludeFromStats: Bool = false,
        healthKitWorkoutUUID: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.date = date
        self.metrics = metrics
        self.excludeFromStats = excludeFromStats
        self.healthKitWorkoutUUID = healthKitWorkoutUUID
    }

    enum CodingKeys: String, CodingKey {
        case id, createdAt, date, metrics, excludeFromStats, healthKitWorkoutUUID
        case coinsEarned, coinBonus, sessionCoins
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        date = try container.decode(String.self, forKey: .date)
        metrics = try container.decode(SwimMetrics.self, forKey: .metrics)
        excludeFromStats = try container.decodeIfPresent(Bool.self, forKey: .excludeFromStats) ?? false
        healthKitWorkoutUUID = try container.decodeIfPresent(String.self, forKey: .healthKitWorkoutUUID)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encode(date, forKey: .date)
        try container.encode(metrics, forKey: .metrics)
        try container.encode(excludeFromStats, forKey: .excludeFromStats)
        try container.encodeIfPresent(healthKitWorkoutUUID, forKey: .healthKitWorkoutUUID)
    }
}

struct HealthKitImportResult: Equatable {
    var importedCount: Int
    var skippedCount: Int
    var totalFound: Int
    var hasMoreAvailable: Bool = false
    var lastImportedSessionId: String?
}

struct MonthRerollEntry: Codable, Equatable {
    var overrides: [String: String]
    var freeUses: Int

    static let empty = MonthRerollEntry(overrides: [:], freeUses: 0)

    init(overrides: [String: String] = [:], freeUses: Int = 0) {
        self.overrides = overrides
        self.freeUses = freeUses
    }

    enum CodingKeys: String, CodingKey {
        case overrides, freeUses, freeUsed, tierIndex, type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let tierIndex = try container.decodeIfPresent(Int.self, forKey: .tierIndex),
           let type = try container.decodeIfPresent(String.self, forKey: .type) {
            overrides = [String(tierIndex): type]
            freeUses = 1
            return
        }
        overrides = try container.decodeIfPresent([String: String].self, forKey: .overrides) ?? [:]
        if let freeUses = try container.decodeIfPresent(Int.self, forKey: .freeUses) {
            self.freeUses = max(0, freeUses)
        } else if try container.decodeIfPresent(Bool.self, forKey: .freeUsed) == true {
            freeUses = 1
        } else {
            freeUses = 0
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(overrides, forKey: .overrides)
        try container.encode(freeUses, forKey: .freeUses)
    }
}

struct YearMonthMedal: Equatable {
    var monthKey: String
    var month: Int
    var tier: String?
    var completedCount: Int
    var challenges: [MonthlyChallenge]
    var earnedAt: String?
    var hasSessions: Bool
}

struct SwimProfile: Codable, Equatable {
    var name: String
    var sex: String
    var age: Int
    var mascotId: String?
    var mascotSwitchMonthKey: String?
    var aiApiKey: String
    var activeAmbient: String?
    var activeWallpaper: String?

    static let `default` = SwimProfile(
        name: "",
        sex: "male",
        age: 30,
        mascotId: nil,
        mascotSwitchMonthKey: nil,
        aiApiKey: "",
        activeAmbient: nil,
        activeWallpaper: nil
    )

    enum CodingKeys: String, CodingKey {
        case name, sex, age, mascotId, mascotSwitchMonthKey, aiApiKey, activeAmbient, activeWallpaper, activeAppIcon
    }

    init(
        name: String,
        sex: String,
        age: Int,
        mascotId: String?,
        mascotSwitchMonthKey: String?,
        aiApiKey: String,
        activeAmbient: String?,
        activeWallpaper: String? = nil
    ) {
        self.name = name
        self.sex = sex
        self.age = age
        self.mascotId = mascotId
        self.mascotSwitchMonthKey = mascotSwitchMonthKey
        self.aiApiKey = aiApiKey
        self.activeAmbient = activeAmbient
        self.activeWallpaper = activeWallpaper
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        sex = try container.decodeIfPresent(String.self, forKey: .sex) ?? "male"
        age = try container.decodeIfPresent(Int.self, forKey: .age) ?? 30
        mascotId = try container.decodeIfPresent(String.self, forKey: .mascotId)
        mascotSwitchMonthKey = try container.decodeIfPresent(String.self, forKey: .mascotSwitchMonthKey)
        aiApiKey = try container.decodeIfPresent(String.self, forKey: .aiApiKey) ?? ""
        activeAmbient = try container.decodeIfPresent(String.self, forKey: .activeAmbient)
        activeWallpaper = try container.decodeIfPresent(String.self, forKey: .activeWallpaper)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(sex, forKey: .sex)
        try container.encode(age, forKey: .age)
        try container.encodeIfPresent(mascotId, forKey: .mascotId)
        try container.encodeIfPresent(mascotSwitchMonthKey, forKey: .mascotSwitchMonthKey)
        try container.encode(aiApiKey, forKey: .aiApiKey)
        try container.encodeIfPresent(activeAmbient, forKey: .activeAmbient)
        try container.encodeIfPresent(activeWallpaper, forKey: .activeWallpaper)
    }
}

struct SwimData: Codable, Equatable {
    var profile: SwimProfile
    var sessions: [SwimSession]
    var monthlyChallengeRerolls: [String: MonthRerollEntry]

    static let empty = SwimData(
        profile: .default,
        sessions: [],
        monthlyChallengeRerolls: [:]
    )

    enum CodingKeys: String, CodingKey {
        case profile, sessions, monthlyChallengeRerolls
        case totalCoins, coinsSpent, spentCoinClaims, wheelSpins
        case challengeRerollCredits, bonusWheelSpinCredits, storeUnlocks, monthlySettlements
    }

    init(
        profile: SwimProfile,
        sessions: [SwimSession],
        monthlyChallengeRerolls: [String: MonthRerollEntry]
    ) {
        self.profile = profile
        self.sessions = sessions
        self.monthlyChallengeRerolls = monthlyChallengeRerolls
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profile = try container.decode(SwimProfile.self, forKey: .profile)
        sessions = try container.decodeIfPresent([SwimSession].self, forKey: .sessions) ?? []
        monthlyChallengeRerolls = try container.decodeIfPresent(
            [String: MonthRerollEntry].self,
            forKey: .monthlyChallengeRerolls
        ) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(profile, forKey: .profile)
        try container.encode(sessions, forKey: .sessions)
        try container.encode(monthlyChallengeRerolls, forKey: .monthlyChallengeRerolls)
    }
}

struct SwimCheats: Codable, Equatable {
    var allMedalsUnlocked: Bool
    var previewMonthlyMedals: Bool

    static let empty = SwimCheats(
        allMedalsUnlocked: false,
        previewMonthlyMedals: false
    )

    enum CodingKeys: String, CodingKey {
        case allMedalsUnlocked, previewMonthlyMedals, allThemesUnlocked
    }

    init(allMedalsUnlocked: Bool, previewMonthlyMedals: Bool) {
        self.allMedalsUnlocked = allMedalsUnlocked
        self.previewMonthlyMedals = previewMonthlyMedals
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        allMedalsUnlocked = try container.decodeIfPresent(Bool.self, forKey: .allMedalsUnlocked) ?? false
        previewMonthlyMedals = try container.decodeIfPresent(Bool.self, forKey: .previewMonthlyMedals) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(allMedalsUnlocked, forKey: .allMedalsUnlocked)
        try container.encode(previewMonthlyMedals, forKey: .previewMonthlyMedals)
    }
}

struct ParsedScreenshotFields: Equatable {
    var date: String?
    var durationSec: Int?
    var distanceM: Int?
    var activeKcal: Int?
    var totalKcal: Int?
    var paceSecPer100m: Int?
    var avgHeartRate: Int?
    var laps: Int?
    var poolLengthM: Int
    var goalM: Int?
    var location: String
    var timeRange: String
    var strokes: StrokeDistances
}

struct ParsedScreenshotResult: Equatable {
    var fields: ParsedScreenshotFields
    var confidence: Int
    var missingDate: Bool
    var warnings: [String]
    var isSwimWorkout: Bool
    var detectedSport: String?
}

struct WeeklyVolumePoint: Identifiable, Equatable {
    var id: String { weekLabel }
    var weekLabel: String
    var distanceM: Int
    var distanceMa: Int?
}

struct ChartSessionPoint: Identifiable, Equatable {
    var id: String
    var date: String
    var dateLabel: String
    var paceSecPer100m: Int?
    var distanceM: Int?
    var activeKcal: Int?
    var totalKcal: Int?
    var avgHeartRate: Int?
    var paceMa: Int?
    var distanceMa: Int?
    var activeKcalMa: Int?
    var avgHeartRateMa: Int?
}

struct CombinedStats: Equatable {
    var sessionCount: Int
    var totalDistanceM: Int
    var totalDurationSec: Int
    var totalActiveKcal: Int
    var totalLaps: Int
    var avgPaceSecPer100m: Int?
    var avgHeartRate: Int?
    var bestPaceSecPer100m: Int?
    var longestDistanceM: Int?
    var firstDate: String?
    var lastDate: String?
}

struct StrokeChartSlice: Identifiable, Equatable {
    var id: String
    var label: String
    var value: Int
}

struct SessionFeedbackSummary: Equatable {
    var insights: [String]
    var badges: [String]
    var coachMessage: String
    var motivation: String
    var benchmarkLevel: SwimLevel
    var highlights: [FeedbackHighlight] = []
    var tip: String = ""
    var mascotMood: String = "happy"
    var aiEnhanced: Bool = false
}

struct FeedbackHighlight: Equatable, Identifiable {
    var id: String { "\(label)-\(value)" }
    let label: String
    let value: String
}

struct BenchmarkBarItem: Identifiable, Equatable {
    var id: String
    var name: String
    var value: Int
    var colorName: String
}

struct BenchmarkTier: Equatable {
    var beginner: Int
    var intermediate: Int
    var advanced: Int
    var median: Int
}

struct PersonalRecord: Equatable {
    var value: Double
    var sessionId: String
    var date: String
}

struct PersonalRecords: Equatable {
    var longestDistance: PersonalRecord?
    var fastestPace: PersonalRecord?
    var mostActiveCalories: PersonalRecord?
    var mostTotalCalories: PersonalRecord?
    var mostLaps: PersonalRecord?
    var longestDuration: PersonalRecord?
    var highestHeartRate: PersonalRecord?
}

struct MedalDefinition: Equatable, Identifiable {
    var id: String
    var category: String
    var tier: String
    var season: String?
}

struct EvaluatedMedal: Equatable, Identifiable {
    var id: String
    var category: String
    var tier: String
    var season: String?
    var earned: Bool
    var earnedAt: String?
    var periods: [String]
    var progress: MedalProgress?
}

struct MedalProgress: Equatable {
    var percent: Int
    var kind: String
    var scope: String
    var current: Int?
    var target: Int
    var best: Int?
    var bestPeriod: String?
}

struct MonthlyChallenge: Equatable, Identifiable {
    var id: String
    var type: String
    var monthKey: String
    var target: Int
    var tierIndex: Int
    var current: Int
    var completed: Bool
}

struct MonthlyChallengeState: Equatable {
    var monthKey: String
    var challenges: [MonthlyChallenge]
    var completedCount: Int
    var tier: String?
    var earnedAt: String?
    var isPreview: Bool = false
}

enum SwimLevel: String {
    case advanced
    case intermediate
    case beginner
    case developing
    case unknown
}

struct MascotSwitchResult: Equatable {
    var allowed: Bool
    var reason: String
}
