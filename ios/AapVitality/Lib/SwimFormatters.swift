import Foundation

enum SwimFormatters {
    static func parseDistanceM(_ raw: String?) -> Int? {
        guard let raw, !raw.isEmpty else { return nil }
        let cleaned = raw.replacingOccurrences(of: ".", with: "")
            .filter(\.isNumber)
        guard let value = Int(cleaned) else { return nil }
        return value
    }

    static func parsePaceSecPer100m(_ raw: String?) -> Int? {
        guard let raw, !raw.isEmpty else { return nil }
        let pattern = #"(\d+)['′](\d{1,2})"#
        if let match = raw.range(of: pattern, options: .regularExpression) {
            let token = String(raw[match])
            let parts = token
                .replacingOccurrences(of: "′", with: "'")
                .split(separator: "'")
            if parts.count == 2,
               let minutes = Int(parts[0]),
               let seconds = Int(parts[1]) {
                return minutes * 60 + seconds
            }
        }
        if let seconds = Int(raw.filter(\.isNumber)), raw.allSatisfy({ $0.isNumber }) {
            return seconds
        }
        return nil
    }

    static func formatPace(_ secPer100m: Int?) -> String {
        guard let secPer100m, secPer100m > 0 else { return "—" }
        let minutes = secPer100m / 60
        let seconds = secPer100m % 60
        return String(format: "%d'%02d\"/100m", minutes, seconds)
    }

    static func formatPaceChartLabel(_ secPer100m: Int?) -> String {
        formatPace(secPer100m).replacingOccurrences(of: "/100m", with: "")
    }

    static func parseDurationSec(_ raw: String?) -> Int? {
        guard let raw, !raw.isEmpty else { return nil }
        let parts = raw.split(separator: ":").compactMap { Int($0) }
        guard parts.allSatisfy({ _ in true }), !parts.isEmpty else { return nil }
        switch parts.count {
        case 3:
            return parts[0] * 3600 + parts[1] * 60 + parts[2]
        case 2:
            return parts[0] * 60 + parts[1]
        default:
            return nil
        }
    }

    static func formatDuration(_ totalSec: Int?) -> String {
        guard let totalSec, totalSec >= 0 else { return "—" }
        let hours = totalSec / 3600
        let minutes = (totalSec % 3600) / 60
        let seconds = totalSec % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func formatDistance(_ meters: Int?) -> String {
        guard let meters, meters >= 0 else { return "—" }
        if meters >= 1000 {
            let km = Double(meters) / 1000.0
            let formatted = km.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.1f", km)
                : String(format: "%.2f", km)
            return formatted.replacingOccurrences(of: ".", with: ",") + " km"
        }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.numberStyle = .decimal
        let value = formatter.string(from: NSNumber(value: meters)) ?? "\(meters)"
        return "\(value) m"
    }

    static func formatDateShort(_ isoDate: String?, locale: Locale = Locale(identifier: "nl_NL")) -> String {
        guard let isoDate, !isoDate.isEmpty else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: isoDate) else { return isoDate }
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: date)
    }

    static func formatDateLong(_ isoDate: String?, locale: Locale = Locale(identifier: "nl_NL")) -> String {
        guard let isoDate, !isoDate.isEmpty else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: isoDate) else { return isoDate }
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }

    static func getPaceChartDomain(_ paceValues: [Int?]) -> ClosedRange<Double>? {
        let paces = paceValues.compactMap { $0 }.filter { $0 > 0 }.map(Double.init)
        guard !paces.isEmpty else { return nil }
        let minPace = paces.min()!
        let maxPace = paces.max()!
        let spread = maxPace - minPace
        let padding = spread == 0 ? 10.0 : max(6.0, ceil(spread * 0.25))
        let lower = max(30.0, floor(minPace - padding))
        let upper = ceil(maxPace + padding)
        return lower...upper
    }
}
