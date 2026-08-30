import Foundation
import HealthKit

struct HealthKitVitalityWorkout: Identifiable, Equatable {
    var id: String
    var date: String
    var workoutType: String
    var durationSec: Int
    var avgHeartRate: Int?
    var zoneMinutes: HRZoneMinutes?
    var activeKcal: Int?
    var startDate: Date
    var endDate: Date
}

enum HealthKitServiceError: LocalizedError {
    case unavailable
    case authorizationDenied

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Apple Health is not available on this device."
        case .authorizationDenied:
            return "Apple Health access was denied. Enable it in Settings → Health → Data Access."
        }
    }
}

enum HealthKitService {
    private static let store = HKHealthStore()

    /// Cap HealthKit samples loaded per sync to avoid memory spikes.
    static let queryLimit = 120

    private static let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        types.insert(HKObjectType.workoutType())
        if let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.insert(steps)
        }
        if let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(energy)
        }
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        if let bodyMass = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            types.insert(bodyMass)
        }
        if let height = HKQuantityType.quantityType(forIdentifier: .height) {
            types.insert(height)
        }
        if let bodyFat = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) {
            types.insert(bodyFat)
        }
        if let leanMass = HKQuantityType.quantityType(forIdentifier: .leanBodyMass) {
            types.insert(leanMass)
        }
        return types
    }()

    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    static var isAuthorizedForWorkouts: Bool {
        guard isAvailable else { return false }
        let status = store.authorizationStatus(for: HKObjectType.workoutType())
        return status == .sharingAuthorized
    }

    /// Read permission cannot be checked directly; use request status and prior prompts instead.
    static func isReadyForLaunchSync() async -> Bool {
        guard isAvailable else { return false }
        if hasRequestedWorkoutAccess { return true }
        let status = await authorizationRequestStatus()
        return status == .unnecessary
    }

    static func markWorkoutAccessRequested() {
        UserDefaults.standard.set(true, forKey: workoutAccessRequestedKey)
    }

    private static let workoutAccessRequestedKey = "HEALTHKIT_WORKOUT_ACCESS_REQUESTED"

    private static var hasRequestedWorkoutAccess: Bool {
        UserDefaults.standard.bool(forKey: workoutAccessRequestedKey)
    }

    private static func authorizationRequestStatus() async -> HKAuthorizationRequestStatus {
        await withCheckedContinuation { continuation in
            store.getRequestStatusForAuthorization(toShare: [], read: readTypes) { status, _ in
                continuation.resume(returning: status)
            }
        }
    }

    static func requestAuthorization() async throws {
        guard isAvailable else { throw HealthKitServiceError.unavailable }
        try await store.requestAuthorization(toShare: [], read: readTypes)
        markWorkoutAccessRequested()
    }

    /// Fetches all workouts (any type) with optional heart-rate zone enrichment.
    static func fetchNewVitalityWorkouts(
        excluding existingUUIDs: Set<String>,
        since: Date,
        maxResults: Int,
        profile: VitalityProfile,
        queryLimit: Int = queryLimit,
        enrichHeartRate: Bool = true
    ) async throws -> (workouts: [HealthKitVitalityWorkout], queriedCount: Int) {
        guard isAvailable else { throw HealthKitServiceError.unavailable }

        let datePredicate = HKQuery.predicateForSamples(
            withStart: since,
            end: nil,
            options: .strictStartDate
        )

        let rawWorkouts = try await queryWorkouts(predicate: datePredicate, limit: queryLimit)
        var mapped: [HealthKitVitalityWorkout] = []
        mapped.reserveCapacity(min(rawWorkouts.count, maxResults))
        let maxHR = VitalityHRZones.maxHeartRate(sex: profile.sex, age: profile.age)

        for workout in rawWorkouts {
            let base = mapVitalityWorkout(workout)
            guard !existingUUIDs.contains(base.id) else { continue }
            var enriched = base
            if enrichHeartRate {
                if enriched.avgHeartRate == nil, let hr = await averageHeartRate(for: workout) {
                    enriched.avgHeartRate = hr
                }
                if let samples = await heartRateSamples(for: workout), !samples.isEmpty {
                    enriched.zoneMinutes = VitalityHRZones.zoneMinutes(from: samples, maxHR: maxHR)
                } else {
                    enriched.zoneMinutes = VitalityHRZones.zoneMinutes(
                        from: enriched.avgHeartRate,
                        durationSec: enriched.durationSec,
                        maxHR: maxHR
                    )
                }
            }
            mapped.append(enriched)
        }

        mapped.sort { $0.startDate < $1.startDate }
        if mapped.count > maxResults {
            mapped = Array(mapped.prefix(maxResults))
        }

        return (mapped, rawWorkouts.count)
    }

    static func fetchDailySteps(since: Date) async throws -> [String: Int] {
        guard isAvailable else { throw HealthKitServiceError.unavailable }
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return [:] }

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: since, end: Date(), options: .strictStartDate)
            var interval = DateComponents()
            interval.day = 1
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: Calendar.current.startOfDay(for: since),
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, collection, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                var result: [String: Int] = [:]
                collection?.enumerateStatistics(from: since, to: Date()) { stats, _ in
                    let steps = stats.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    if steps > 0 {
                        result[dateKeyFormatter.string(from: stats.startDate)] = Int(steps.rounded())
                    }
                }
                continuation.resume(returning: result)
            }
            store.execute(query)
        }
    }

    static func fetchTodaySteps() async throws -> Int {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let byDate = try await fetchDailySteps(since: startOfDay)
        return byDate[dateKeyFormatter.string(from: now)] ?? 0
    }

    static func fetchDailySleep(since: Date) async throws -> [String: Int] {
        guard isAvailable else { throw HealthKitServiceError.unavailable }
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [:] }

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: since, end: Date(), options: .strictStartDate)
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                var result: [String: Int] = [:]
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                ]
                for sample in (samples as? [HKCategorySample]) ?? [] {
                    guard asleepValues.contains(sample.value) else { continue }
                    let minutes = max(0, Int(sample.endDate.timeIntervalSince(sample.startDate) / 60))
                    guard minutes > 0 else { continue }
                    let day = dateKeyFormatter.string(from: sample.endDate)
                    result[day, default: 0] += minutes
                }
                continuation.resume(returning: result)
            }
            store.execute(query)
        }
    }

    static func fetchDailyBodyMass(since: Date) async throws -> [String: Double] {
        guard isAvailable else { throw HealthKitServiceError.unavailable }
        guard let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return [:] }
        return try await fetchLatestDailyQuantity(
            type: bodyMassType,
            unit: .gramUnit(with: .kilo),
            since: since,
            scalePercentTo100: false
        )
    }

    static func fetchDailyBodyFat(since: Date) async throws -> [String: Double] {
        guard isAvailable else { throw HealthKitServiceError.unavailable }
        guard let bodyFatType = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) else { return [:] }
        return try await fetchLatestDailyQuantity(
            type: bodyFatType,
            unit: .percent(),
            since: since,
            scalePercentTo100: true
        )
    }

    static func fetchDailyLeanBodyMass(since: Date) async throws -> [String: Double] {
        guard isAvailable else { throw HealthKitServiceError.unavailable }
        guard let leanType = HKQuantityType.quantityType(forIdentifier: .leanBodyMass) else { return [:] }
        return try await fetchLatestDailyQuantity(
            type: leanType,
            unit: .gramUnit(with: .kilo),
            since: since,
            scalePercentTo100: false
        )
    }

    static func fetchLatestHeightCm() async throws -> Double? {
        guard isAvailable else { throw HealthKitServiceError.unavailable }
        guard let heightType = HKQuantityType.quantityType(forIdentifier: .height) else { return nil }

        return try await withCheckedThrowingContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: heightType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let sample = (samples as? [HKQuantitySample])?.first else {
                    continuation.resume(returning: nil)
                    return
                }
                let meters = sample.quantity.doubleValue(for: .meter())
                continuation.resume(returning: meters * 100)
            }
            store.execute(query)
        }
    }

    private static func fetchLatestDailyQuantity(
        type: HKQuantityType,
        unit: HKUnit,
        since: Date,
        scalePercentTo100: Bool
    ) async throws -> [String: Double] {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: since, end: Date(), options: .strictStartDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                var result: [String: Double] = [:]
                for sample in (samples as? [HKQuantitySample]) ?? [] {
                    let day = dateKeyFormatter.string(from: sample.endDate)
                    let raw = sample.quantity.doubleValue(for: unit)
                    let value = scalePercentTo100 ? raw * 100 : raw
                    result[day] = value
                }
                continuation.resume(returning: result)
            }
            store.execute(query)
        }
    }

    private static func mapVitalityWorkout(_ workout: HKWorkout) -> HealthKitVitalityWorkout {
        let durationSec = max(0, Int(workout.duration.rounded()))
        let activeKcal = workout.totalEnergyBurned.map { Int($0.doubleValue(for: .kilocalorie()).rounded()) }
        let date = dateKeyFormatter.string(from: workout.startDate)
        return HealthKitVitalityWorkout(
            id: workout.uuid.uuidString,
            date: date,
            workoutType: workout.workoutActivityType.vitalityName,
            durationSec: durationSec,
            avgHeartRate: nil,
            zoneMinutes: nil,
            activeKcal: activeKcal,
            startDate: workout.startDate,
            endDate: workout.endDate
        )
    }

    private static func heartRateSamples(for workout: HKWorkout) async -> [(bpm: Int, durationSec: Int)]? {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return nil }
        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: workout.startDate,
                end: workout.endDate,
                options: .strictStartDate
            )
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: hrType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                guard let quantitySamples = samples as? [HKQuantitySample], quantitySamples.count >= 2 else {
                    continuation.resume(returning: nil)
                    return
                }
                var samplesOut: [(bpm: Int, durationSec: Int)] = []
                for index in 0..<(quantitySamples.count - 1) {
                    let current = quantitySamples[index]
                    let next = quantitySamples[index + 1]
                    let bpm = Int(current.quantity.doubleValue(
                        for: HKUnit.count().unitDivided(by: HKUnit.minute())
                    ).rounded())
                    let duration = max(1, Int(next.startDate.timeIntervalSince(current.startDate)))
                    samplesOut.append((bpm: bpm, durationSec: duration))
                }
                continuation.resume(returning: samplesOut)
            }
            store.execute(query)
        }
    }

    private static func queryWorkouts(predicate: NSPredicate, limit: Int) async throws -> [HKWorkout] {
        try await withCheckedThrowingContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: workouts)
            }
            store.execute(query)
        }
    }

    private static func averageHeartRate(for workout: HKWorkout) async -> Int? {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return nil }
        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: workout.startDate,
                end: workout.endDate,
                options: .strictStartDate
            )
            let query = HKStatisticsQuery(
                quantityType: hrType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, stats, _ in
                guard let quantity = stats?.averageQuantity() else {
                    continuation.resume(returning: nil)
                    return
                }
                let bpm = quantity.doubleValue(
                    for: HKUnit.count().unitDivided(by: HKUnit.minute())
                )
                continuation.resume(returning: Int(bpm.rounded()))
            }
            store.execute(query)
        }
    }

    private static let dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

private extension HKWorkoutActivityType {
    var vitalityName: String {
        switch self {
        case .running: return "running"
        case .walking: return "walking"
        case .cycling: return "cycling"
        case .swimming: return "swimming"
        case .yoga: return "yoga"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "strength"
        case .highIntensityIntervalTraining: return "hiit"
        case .hiking: return "hiking"
        case .elliptical: return "elliptical"
        case .rowing: return "rowing"
        default: return "other"
        }
    }
}
