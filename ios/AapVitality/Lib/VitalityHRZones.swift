import Foundation

enum VitalityHRZones {
    /// Estimated maximum heart rate adjusted for sex and age.
    static func maxHeartRate(sex: String, age: Int) -> Int {
        let clampedAge = max(10, min(99, age))
        if sex.lowercased() == "female" {
            return max(140, 206 - Int((0.88 * Double(clampedAge)).rounded()))
        }
        return max(140, 220 - clampedAge)
    }

    static func zone(for heartRate: Int, maxHR: Int) -> Int {
        guard maxHR > 0, heartRate > 0 else { return 0 }
        let pct = Double(heartRate) / Double(maxHR) * 100
        switch pct {
        case ..<50: return 0
        case 50..<60: return 1
        case 60..<70: return 2
        case 70..<80: return 3
        case 80..<90: return 4
        default: return 5
        }
    }

    static func zoneMinutes(from heartRates: [(bpm: Int, durationSec: Int)], maxHR: Int) -> HRZoneMinutes {
        var zoneSeconds = [Int](repeating: 0, count: 6)
        for sample in heartRates {
            let z = zone(for: sample.bpm, maxHR: maxHR)
            guard (1...5).contains(z) else { continue }
            zoneSeconds[z] += sample.durationSec
        }
        return HRZoneMinutes(
            zone1: zoneSeconds[1] / 60,
            zone2: zoneSeconds[2] / 60,
            zone3: zoneSeconds[3] / 60,
            zone4: zoneSeconds[4] / 60,
            zone5: zoneSeconds[5] / 60
        )
    }

    static func resolvedZoneMinutes(
        stored: HRZoneMinutes?,
        averageHeartRate: Int?,
        durationSec: Int,
        maxHR: Int
    ) -> HRZoneMinutes {
        let durationMinutes = max(1, durationSec / 60)
        if let stored, stored.total <= durationMinutes {
            return stored
        }
        return zoneMinutes(from: averageHeartRate, durationSec: durationSec, maxHR: maxHR)
    }

    static func zoneMinutes(from averageHeartRate: Int?, durationSec: Int, maxHR: Int) -> HRZoneMinutes {
        guard let avg = averageHeartRate, avg > 0, durationSec >= 60 else {
            return HRZoneMinutes()
        }
        let z = zone(for: avg, maxHR: maxHR)
        let minutes = max(1, durationSec / 60)
        var zones = HRZoneMinutes()
        switch z {
        case 1: zones.zone1 = minutes
        case 2: zones.zone2 = minutes
        case 3: zones.zone3 = minutes
        case 4: zones.zone4 = minutes
        case 5: zones.zone5 = minutes
        default: break
        }
        return zones
    }

    static func zoneBonusPoints(_ zones: HRZoneMinutes) -> Int {
        zones.zone1 * 1 + zones.zone2 * 2 + zones.zone3 * 4 + zones.zone4 * 6 + zones.zone5 * 8
    }
}
