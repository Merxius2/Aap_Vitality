import Foundation
import HealthKit

struct HealthKitSwimWorkout: Identifiable, Equatable {
    var id: String
    var date: String
    var metrics: SwimMetrics
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
        if let distance = HKQuantityType.quantityType(forIdentifier: .distanceSwimming) {
            types.insert(distance)
        }
        if let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(energy)
        }
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
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

    /// Fetches swim workouts not yet imported, optionally enriching each with heart rate data.
    static func fetchNewSwimWorkouts(
        excluding existingUUIDs: Set<String>,
        since: Date,
        maxResults: Int,
        queryLimit: Int = queryLimit,
        enrichHeartRate: Bool = true
    ) async throws -> (workouts: [HealthKitSwimWorkout], queriedCount: Int) {
        guard isAvailable else { throw HealthKitServiceError.unavailable }

        let workoutPredicate = HKQuery.predicateForWorkouts(with: .swimming)
        let datePredicate = HKQuery.predicateForSamples(
            withStart: since,
            end: nil,
            options: .strictStartDate
        )
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            workoutPredicate,
            datePredicate,
        ])

        let rawWorkouts = try await queryWorkouts(predicate: predicate, limit: queryLimit)
        var mapped: [HealthKitSwimWorkout] = []
        mapped.reserveCapacity(min(rawWorkouts.count, maxResults))

        for workout in rawWorkouts {
            let base = mapWorkout(workout)
            guard !existingUUIDs.contains(base.id) else { continue }
            let enriched = enrichHeartRate
                ? await enrichWorkoutMetrics(workout, base: base.metrics)
                : enrichWorkoutMetricsSync(workout, base: base.metrics)
            mapped.append(HealthKitSwimWorkout(
                id: base.id,
                date: base.date,
                metrics: enriched,
                startDate: base.startDate,
                endDate: base.endDate
            ))
        }

        mapped.sort { $0.startDate < $1.startDate }
        if mapped.count > maxResults {
            mapped = Array(mapped.prefix(maxResults))
        }

        return (mapped, rawWorkouts.count)
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

    private static func mapWorkout(_ workout: HKWorkout) -> HealthKitSwimWorkout {
        let durationSec = max(0, Int(workout.duration.rounded()))
        let distanceM = workout.totalDistance.map { Int($0.doubleValue(for: .meter()).rounded()) }
        let activeKcal = workout.totalEnergyBurned.map { Int($0.doubleValue(for: .kilocalorie()).rounded()) }

        var paceSecPer100m: Int?
        if let distanceM, distanceM > 0, durationSec > 0 {
            paceSecPer100m = Int((Double(durationSec) / Double(distanceM)) * 100.0)
        }

        let date = dateKeyFormatter.string(from: workout.startDate)
        let timeRange = "\(timeFormatter.string(from: workout.startDate))–\(timeFormatter.string(from: workout.endDate))"
        let location: String
        if let swimLocation = workout.metadata?[HKMetadataKeySwimmingLocationType] as? Int,
           swimLocation == HKWorkoutSwimmingLocationType.openWater.rawValue {
            location = "Open water"
        } else {
            location = ""
        }

        var poolLengthM = 25
        if let lapLength = workout.metadata?[HKMetadataKeyLapLength] as? HKQuantity {
            poolLengthM = max(1, Int(lapLength.doubleValue(for: .meter()).rounded()))
        }

        var laps: Int?
        if let distanceM, poolLengthM > 0 {
            laps = max(1, distanceM / poolLengthM)
        }

        return HealthKitSwimWorkout(
            id: workout.uuid.uuidString,
            date: date,
            metrics: SwimMetrics(
                durationSec: durationSec > 0 ? durationSec : nil,
                distanceM: distanceM,
                activeKcal: activeKcal,
                totalKcal: activeKcal,
                paceSecPer100m: paceSecPer100m,
                avgHeartRate: nil,
                laps: laps,
                poolLengthM: poolLengthM,
                goalM: nil,
                location: location,
                timeRange: timeRange,
                strokes: .empty
            ),
            startDate: workout.startDate,
            endDate: workout.endDate
        )
    }

    private static func enrichWorkoutMetricsSync(_ workout: HKWorkout, base: SwimMetrics) -> SwimMetrics {
        var metrics = base
        if metrics.laps == nil, let laps = lapCount(for: workout) {
            metrics.laps = laps
        } else if metrics.laps == nil,
                  let distanceM = metrics.distanceM,
                  metrics.poolLengthM > 0 {
            metrics.laps = max(1, distanceM / metrics.poolLengthM)
        }
        return metrics
    }

    private static func enrichWorkoutMetrics(_ workout: HKWorkout, base: SwimMetrics) async -> SwimMetrics {
        var metrics = base
        if metrics.avgHeartRate == nil, let hr = await averageHeartRate(for: workout) {
            metrics.avgHeartRate = hr
        }
        if metrics.laps == nil, let laps = lapCount(for: workout) {
            metrics.laps = laps
        } else if metrics.laps == nil,
                  let distanceM = metrics.distanceM,
                  metrics.poolLengthM > 0 {
            metrics.laps = max(1, distanceM / metrics.poolLengthM)
        }
        return metrics
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

    private static func lapCount(for workout: HKWorkout) -> Int? {
        guard let events = workout.workoutEvents else { return nil }
        let laps = events.filter { $0.type == .lap }
        return laps.isEmpty ? nil : laps.count
    }

    private static let dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
