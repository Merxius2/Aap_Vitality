import Foundation

enum ProgressChartScope: String, CaseIterable, Identifiable {
    case week
    case month
    case quarter
    case ytd
    case allTime

    var id: String { rawValue }

    var nameKey: String {
        switch self {
        case .week: return "progress.chartScope.week"
        case .month: return "progress.chartScope.month"
        case .quarter: return "progress.chartScope.quarter"
        case .ytd: return "progress.chartScope.ytd"
        case .allTime: return "progress.chartScope.allTime"
        }
    }

    func startDateString(referenceDate: Date = Date(), calendar: Calendar = .current) -> String? {
        let formatter = Self.dateFormatter
        switch self {
        case .allTime:
            return nil
        case .week:
            var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: referenceDate)
            components.weekday = 2
            let weekStart = calendar.date(from: components) ?? referenceDate
            return formatter.string(from: weekStart)
        case .month:
            let components = calendar.dateComponents([.year, .month], from: referenceDate)
            let monthStart = calendar.date(from: components) ?? referenceDate
            return formatter.string(from: monthStart)
        case .quarter:
            let month = calendar.component(.month, from: referenceDate)
            let quarterStartMonth = ((month - 1) / 3) * 3 + 1
            var components = calendar.dateComponents([.year], from: referenceDate)
            components.month = quarterStartMonth
            components.day = 1
            let quarterStart = calendar.date(from: components) ?? referenceDate
            return formatter.string(from: quarterStart)
        case .ytd:
            let year = calendar.component(.year, from: referenceDate)
            return "\(year)-01-01"
        }
    }

    func endDateString(referenceDate: Date = Date(), calendar: Calendar = .current) -> String {
        Self.dateFormatter.string(from: referenceDate)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

extension SwimAnalysis {
    static func filterSessions(
        _ sessions: [SwimSession],
        scope: ProgressChartScope,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [SwimSession] {
        let stats = statsSessions(sessions)
        guard let start = scope.startDateString(referenceDate: referenceDate, calendar: calendar) else {
            return stats
        }
        let end = scope.endDateString(referenceDate: referenceDate, calendar: calendar)
        return stats.filter { $0.date >= start && $0.date <= end }
    }

    static func strokeChartData(_ sessions: [SwimSession], t: TranslationService) -> [StrokeChartSlice] {
        var totals: [String: Int] = [
            "mixedM": 0,
            "breaststrokeM": 0,
            "freestyleM": 0,
            "backstrokeM": 0,
            "butterflyM": 0,
        ]

        for session in statsSessions(sessions) {
            let strokes = session.metrics.strokes
            totals["mixedM", default: 0] += strokes.mixedM ?? 0
            totals["breaststrokeM", default: 0] += strokes.breaststrokeM ?? 0
            totals["freestyleM", default: 0] += strokes.freestyleM ?? 0
            totals["backstrokeM", default: 0] += strokes.backstrokeM ?? 0
            totals["butterflyM", default: 0] += strokes.butterflyM ?? 0
        }

        let labels: [(String, String)] = [
            ("mixedM", t.t("strokes.mixed")),
            ("breaststrokeM", t.t("strokes.breaststroke")),
            ("freestyleM", t.t("strokes.freestyle")),
            ("backstrokeM", t.t("strokes.backstroke")),
            ("butterflyM", t.t("strokes.butterfly")),
        ]

        return labels.compactMap { id, label in
            let value = totals[id] ?? 0
            guard value > 0 else { return nil }
            return StrokeChartSlice(id: id, label: label, value: value)
        }
    }
}
