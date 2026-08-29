import Foundation

enum ChartMovingAverage {
    static func movingAverage(_ values: [Int?], windowSize: Int = 3) -> [Int?] {
        guard !values.isEmpty else { return [] }

        return values.indices.map { index in
            let start = max(0, index - windowSize + 1)
            let window = values[start...index].compactMap { $0 }
            guard !window.isEmpty else { return nil }
            let sum = window.reduce(0, +)
            return sum / window.count
        }
    }

    static func enrichChartSessions(_ points: [ChartSessionPoint]) -> [ChartSessionPoint] {
        let paceValues = points.map(\.paceSecPer100m)
        let distanceValues = points.map(\.distanceM)
        let activeKcalValues = points.map(\.activeKcal)
        let heartRateValues = points.map(\.avgHeartRate)

        let paceMa = movingAverage(paceValues)
        let distanceMa = movingAverage(distanceValues)
        let activeKcalMa = movingAverage(activeKcalValues)
        let heartRateMa = movingAverage(heartRateValues)

        return points.enumerated().map { index, point in
            var next = point
            next.paceMa = paceMa[index]
            next.distanceMa = distanceMa[index]
            next.activeKcalMa = activeKcalMa[index]
            next.avgHeartRateMa = heartRateMa[index]
            return next
        }
    }

    static func enrichWeeklyVolume(_ points: [WeeklyVolumePoint]) -> [WeeklyVolumePoint] {
        let distanceValues = points.map { Optional($0.distanceM) }
        let distanceMa = movingAverage(distanceValues)

        return points.enumerated().map { index, point in
            var next = point
            next.distanceMa = distanceMa[index]
            return next
        }
    }
}
