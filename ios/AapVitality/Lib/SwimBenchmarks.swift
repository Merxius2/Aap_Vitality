import Foundation

enum SwimBenchmarks {
    static func allBenchmarksForTesting() -> [String: [String: BenchmarkTier]] {
        benchmarks
    }

    private static let benchmarks: [String: [String: BenchmarkTier]] = [
        "male": [
            "18-24": BenchmarkTier(beginner: 148, intermediate: 125, advanced: 98, median: 125),
            "25-29": BenchmarkTier(beginner: 152, intermediate: 128, advanced: 100, median: 128),
            "30-34": BenchmarkTier(beginner: 156, intermediate: 130, advanced: 102, median: 130),
            "35-39": BenchmarkTier(beginner: 160, intermediate: 134, advanced: 106, median: 134),
            "40-44": BenchmarkTier(beginner: 166, intermediate: 138, advanced: 110, median: 138),
            "45-49": BenchmarkTier(beginner: 172, intermediate: 143, advanced: 114, median: 143),
            "50-54": BenchmarkTier(beginner: 178, intermediate: 148, advanced: 118, median: 148),
            "55-59": BenchmarkTier(beginner: 184, intermediate: 153, advanced: 122, median: 153),
            "60-64": BenchmarkTier(beginner: 192, intermediate: 160, advanced: 128, median: 160),
            "65-69": BenchmarkTier(beginner: 202, intermediate: 168, advanced: 134, median: 168),
            "70+": BenchmarkTier(beginner: 212, intermediate: 176, advanced: 140, median: 176)
        ],
        "female": [
            "18-24": BenchmarkTier(beginner: 162, intermediate: 138, advanced: 112, median: 138),
            "25-29": BenchmarkTier(beginner: 166, intermediate: 142, advanced: 114, median: 142),
            "30-34": BenchmarkTier(beginner: 170, intermediate: 145, advanced: 117, median: 145),
            "35-39": BenchmarkTier(beginner: 174, intermediate: 149, advanced: 120, median: 149),
            "40-44": BenchmarkTier(beginner: 180, intermediate: 154, advanced: 124, median: 154),
            "45-49": BenchmarkTier(beginner: 186, intermediate: 159, advanced: 128, median: 159),
            "50-54": BenchmarkTier(beginner: 192, intermediate: 164, advanced: 132, median: 164),
            "55-59": BenchmarkTier(beginner: 198, intermediate: 169, advanced: 136, median: 169),
            "60-64": BenchmarkTier(beginner: 208, intermediate: 176, advanced: 142, median: 176),
            "65-69": BenchmarkTier(beginner: 218, intermediate: 184, advanced: 148, median: 184),
            "70+": BenchmarkTier(beginner: 228, intermediate: 192, advanced: 154, median: 192)
        ]
    ]

    static func ageGroup(for age: Int) -> String {
        switch age {
        case ..<25: return "18-24"
        case ..<30: return "25-29"
        case ..<35: return "30-34"
        case ..<40: return "35-39"
        case ..<45: return "40-44"
        case ..<50: return "45-49"
        case ..<55: return "50-54"
        case ..<60: return "55-59"
        case ..<65: return "60-64"
        case ..<70: return "65-69"
        default: return "70+"
        }
    }

    static func benchmark(for sex: String, age: Int) -> BenchmarkTier {
        let group = ageGroup(for: age)
        let sexKey = sex == "female" ? "female" : "male"
        return benchmarks[sexKey]?[group] ?? benchmarks["male"]!["30-34"]!
    }

    static func swimLevel(paceSecPer100m: Int?, benchmark: BenchmarkTier) -> SwimLevel {
        guard let paceSecPer100m else { return .unknown }
        if paceSecPer100m <= benchmark.advanced { return .advanced }
        if paceSecPer100m <= benchmark.intermediate { return .intermediate }
        if paceSecPer100m <= benchmark.beginner { return .beginner }
        return .developing
    }

    static func levelLabel(_ level: SwimLevel, t: TranslationService) -> String {
        t.t("benchmark.levels.\(level.rawValue)")
    }

    static func levelLabel(_ level: SwimLevel) -> String {
        switch level {
        case .advanced: return "Advanced"
        case .intermediate: return "Intermediate"
        case .beginner: return "Beginner"
        case .developing: return "Developing"
        case .unknown: return "Unknown"
        }
    }

    static func computePacePercentile(paceSecPer100m: Int?, benchmark: BenchmarkTier) -> Int {
        guard let paceSecPer100m else { return 50 }
        if paceSecPer100m <= benchmark.advanced {
            return min(99, 85 + (benchmark.advanced - paceSecPer100m) / 2)
        }
        if paceSecPer100m <= benchmark.intermediate {
            let range = benchmark.intermediate - benchmark.advanced
            let pos = benchmark.intermediate - paceSecPer100m
            return 60 + Int((Double(pos) / Double(max(range, 1))) * 25)
        }
        if paceSecPer100m <= benchmark.beginner {
            let range = benchmark.beginner - benchmark.intermediate
            let pos = benchmark.beginner - paceSecPer100m
            return 35 + Int((Double(pos) / Double(max(range, 1))) * 25)
        }
        let slower = paceSecPer100m - benchmark.beginner
        return max(5, 35 - slower / 3)
    }

    static func paceVsMedian(paceSecPer100m: Int?, benchmark: BenchmarkTier) -> String {
        guard let paceSecPer100m else { return "below" }
        return paceSecPer100m <= benchmark.median ? "above" : "below"
    }

    static func benchmarkChartData(paceSecPer100m: Int?, sex: String, age: Int) -> [BenchmarkBarItem] {
        let benchmark = benchmark(for: sex, age: age)
        var items = [
            BenchmarkBarItem(id: "advanced", name: "Advanced", value: benchmark.advanced, colorName: "green"),
            BenchmarkBarItem(id: "intermediate", name: "Intermediate", value: benchmark.intermediate, colorName: "blue"),
            BenchmarkBarItem(id: "median", name: "Median", value: benchmark.median, colorName: "purple"),
            BenchmarkBarItem(id: "beginner", name: "Beginner", value: benchmark.beginner, colorName: "orange")
        ]
        if let paceSecPer100m {
            items.append(BenchmarkBarItem(id: "you", name: "Your pace", value: paceSecPer100m, colorName: "red"))
        }
        return items
    }
}
