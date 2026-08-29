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

struct VitalityProfile: Codable, Equatable {
    var name: String
    var sex: String
    var age: Int
    var mascotId: String?
    var mascotSwitchMonthKey: String?
    var aiApiKey: String
    var activeAmbient: String?
    var activeWallpaper: String?

    static let `default` = VitalityProfile(
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

struct VitalityData: Codable, Equatable {
    var profile: VitalityProfile
    var sessions: [SwimSession]
    var monthlyChallengeRerolls: [String: MonthRerollEntry]
    var dailyRecords: [DailyVitalityRecord]
    var goalState: VitalityGoalState

    static let empty = VitalityData(
        profile: .default,
        sessions: [],
        monthlyChallengeRerolls: [:],
        dailyRecords: [],
        goalState: .empty
    )

    enum CodingKeys: String, CodingKey {
        case profile, sessions, monthlyChallengeRerolls, dailyRecords, goalState
        case totalCoins, coinsSpent, spentCoinClaims, wheelSpins
        case challengeRerollCredits, bonusWheelSpinCredits, storeUnlocks, monthlySettlements
    }

    init(
        profile: VitalityProfile,
        sessions: [SwimSession],
        monthlyChallengeRerolls: [String: MonthRerollEntry],
        dailyRecords: [DailyVitalityRecord] = [],
        goalState: VitalityGoalState = .empty
    ) {
        self.profile = profile
        self.sessions = sessions
        self.monthlyChallengeRerolls = monthlyChallengeRerolls
        self.dailyRecords = dailyRecords
        self.goalState = goalState
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profile = try container.decode(VitalityProfile.self, forKey: .profile)
        sessions = try container.decodeIfPresent([SwimSession].self, forKey: .sessions) ?? []
        monthlyChallengeRerolls = try container.decodeIfPresent(
            [String: MonthRerollEntry].self,
            forKey: .monthlyChallengeRerolls
        ) ?? [:]
        dailyRecords = try container.decodeIfPresent([DailyVitalityRecord].self, forKey: .dailyRecords) ?? []
        goalState = try container.decodeIfPresent(VitalityGoalState.self, forKey: .goalState) ?? .empty
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(profile, forKey: .profile)
        try container.encode(sessions, forKey: .sessions)
        try container.encode(monthlyChallengeRerolls, forKey: .monthlyChallengeRerolls)
        try container.encode(dailyRecords, forKey: .dailyRecords)
        try container.encode(goalState, forKey: .goalState)
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

struct HRZoneMinutes: Codable, Equatable {
    var zone1: Int = 0
    var zone2: Int = 0
    var zone3: Int = 0
    var zone4: Int = 0
    var zone5: Int = 0

    var total: Int { zone1 + zone2 + zone3 + zone4 + zone5 }
}

struct VitalityWorkout: Codable, Identifiable, Equatable {
    var id: String
    var date: String
    var workoutType: String
    var durationSec: Int
    var avgHeartRate: Int?
    var zoneMinutes: HRZoneMinutes?
    var activeKcal: Int?
    var healthKitWorkoutUUID: String?
    var pointsEarned: Int = 0
}

struct DailyVitalityRecord: Codable, Identifiable, Equatable {
    var id: String
    var date: String
    var steps: Int
    var stepPoints: Int
    var workoutPoints: Int
    var sleepMinutes: Int
    var sleepPoints: Int
    var totalPoints: Int
    var workouts: [VitalityWorkout]
    var stepTiersReached: [Int]

    init(
        id: String,
        date: String,
        steps: Int,
        stepPoints: Int,
        workoutPoints: Int,
        sleepMinutes: Int = 0,
        sleepPoints: Int = 0,
        totalPoints: Int,
        workouts: [VitalityWorkout],
        stepTiersReached: [Int]
    ) {
        self.id = id
        self.date = date
        self.steps = steps
        self.stepPoints = stepPoints
        self.workoutPoints = workoutPoints
        self.sleepMinutes = sleepMinutes
        self.sleepPoints = sleepPoints
        self.totalPoints = totalPoints
        self.workouts = workouts
        self.stepTiersReached = stepTiersReached
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        date = try container.decode(String.self, forKey: .date)
        steps = try container.decode(Int.self, forKey: .steps)
        stepPoints = try container.decode(Int.self, forKey: .stepPoints)
        workoutPoints = try container.decode(Int.self, forKey: .workoutPoints)
        sleepMinutes = try container.decodeIfPresent(Int.self, forKey: .sleepMinutes) ?? 0
        sleepPoints = try container.decodeIfPresent(Int.self, forKey: .sleepPoints) ?? 0
        totalPoints = try container.decode(Int.self, forKey: .totalPoints)
        workouts = try container.decode([VitalityWorkout].self, forKey: .workouts)
        stepTiersReached = try container.decode([Int].self, forKey: .stepTiersReached)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(steps, forKey: .steps)
        try container.encode(stepPoints, forKey: .stepPoints)
        try container.encode(workoutPoints, forKey: .workoutPoints)
        try container.encode(sleepMinutes, forKey: .sleepMinutes)
        try container.encode(sleepPoints, forKey: .sleepPoints)
        try container.encode(totalPoints, forKey: .totalPoints)
        try container.encode(workouts, forKey: .workouts)
        try container.encode(stepTiersReached, forKey: .stepTiersReached)
    }
}

struct MonthlyGoalCompletion: Codable, Equatable {
    var completedAt: String
    var daysToComplete: Int
    var targetPoints: Int
    var earnedPoints: Int
}

struct VitalityGoalState: Codable, Equatable {
    var monthlyTargets: [String: Int]
    var weeklyTargets: [String: Int]
    var yearlyTargets: [String: Int]
    var monthlyCompletions: [String: MonthlyGoalCompletion]
    var goalBoostFactor: Double
    var streakShieldsAvailable: Int
    var shieldUsedDates: [String]
    var streakShieldMonthKey: String?

    static let empty = VitalityGoalState(
        monthlyTargets: [:],
        weeklyTargets: [:],
        yearlyTargets: [:],
        monthlyCompletions: [:],
        goalBoostFactor: 1.0,
        streakShieldsAvailable: 1,
        shieldUsedDates: [],
        streakShieldMonthKey: nil
    )

    init(
        monthlyTargets: [String: Int],
        weeklyTargets: [String: Int],
        yearlyTargets: [String: Int],
        monthlyCompletions: [String: MonthlyGoalCompletion],
        goalBoostFactor: Double,
        streakShieldsAvailable: Int = 1,
        shieldUsedDates: [String] = [],
        streakShieldMonthKey: String? = nil
    ) {
        self.monthlyTargets = monthlyTargets
        self.weeklyTargets = weeklyTargets
        self.yearlyTargets = yearlyTargets
        self.monthlyCompletions = monthlyCompletions
        self.goalBoostFactor = goalBoostFactor
        self.streakShieldsAvailable = streakShieldsAvailable
        self.shieldUsedDates = shieldUsedDates
        self.streakShieldMonthKey = streakShieldMonthKey
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        monthlyTargets = try container.decodeIfPresent([String: Int].self, forKey: .monthlyTargets) ?? [:]
        weeklyTargets = try container.decodeIfPresent([String: Int].self, forKey: .weeklyTargets) ?? [:]
        yearlyTargets = try container.decodeIfPresent([String: Int].self, forKey: .yearlyTargets) ?? [:]
        monthlyCompletions = try container.decodeIfPresent(
            [String: MonthlyGoalCompletion].self,
            forKey: .monthlyCompletions
        ) ?? [:]
        goalBoostFactor = try container.decodeIfPresent(Double.self, forKey: .goalBoostFactor) ?? 1.0
        streakShieldsAvailable = try container.decodeIfPresent(Int.self, forKey: .streakShieldsAvailable) ?? 1
        shieldUsedDates = try container.decodeIfPresent([String].self, forKey: .shieldUsedDates) ?? []
        streakShieldMonthKey = try container.decodeIfPresent(String.self, forKey: .streakShieldMonthKey)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(monthlyTargets, forKey: .monthlyTargets)
        try container.encode(weeklyTargets, forKey: .weeklyTargets)
        try container.encode(yearlyTargets, forKey: .yearlyTargets)
        try container.encode(monthlyCompletions, forKey: .monthlyCompletions)
        try container.encode(goalBoostFactor, forKey: .goalBoostFactor)
        try container.encode(streakShieldsAvailable, forKey: .streakShieldsAvailable)
        try container.encode(shieldUsedDates, forKey: .shieldUsedDates)
        try container.encodeIfPresent(streakShieldMonthKey, forKey: .streakShieldMonthKey)
    }
}

struct VitalityStreakSnapshot: Equatable {
    var currentStreak: Int
    var shieldsAvailable: Int
    var lastShieldUsedDate: String?
}

struct VitalityLevelSnapshot: Equatable {
    var level: Int
    var titleKey: String
    var lifetimePoints: Int
    var pointsIntoLevel: Int
    var pointsToNextLevel: Int
    var progressPercent: Int
}

struct AchievementPathProgress: Equatable, Identifiable {
    var id: String
    var titleKey: String
    var medalIds: [String]
    var completedCount: Int
    var totalCount: Int
    var nextMedalId: String?
    var progressPercent: Int
}

struct WorkoutTypeBadge: Equatable, Identifiable {
    var id: String
    var workoutType: String
    var tier: String
    var count: Int
    var target: Int
}

struct VitalityGoalSnapshot: Equatable {
    var monthKey: String
    var weekKey: String
    var yearKey: String
    var monthlyTarget: Int
    var monthlyEarned: Int
    var weeklyTarget: Int
    var weeklyEarned: Int
    var yearlyTarget: Int
    var yearlyEarned: Int

    var monthlyPercent: Int {
        guard monthlyTarget > 0 else { return 0 }
        return min(100, Int((Double(monthlyEarned) / Double(monthlyTarget) * 100).rounded()))
    }

    var weeklyPercent: Int {
        guard weeklyTarget > 0 else { return 0 }
        return min(100, Int((Double(weeklyEarned) / Double(weeklyTarget) * 100).rounded()))
    }

    var yearlyPercent: Int {
        guard yearlyTarget > 0 else { return 0 }
        return min(100, Int((Double(yearlyEarned) / Double(yearlyTarget) * 100).rounded()))
    }
}

struct MascotSwitchResult: Equatable {
    var allowed: Bool
    var reason: String
}
