import Foundation

enum ScreenshotParser {
    private static let dutchMonths: [String: Int] = [
        "jan": 1, "feb": 2, "mrt": 3, "mar": 3, "apr": 4, "mei": 5, "may": 5,
        "jun": 6, "jul": 7, "aug": 8, "sep": 9, "okt": 10, "oct": 10, "nov": 11, "dec": 12
    ]

    static func normalizeText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{2013}", with: "-")
            .replacingOccurrences(of: "\u{2014}", with: "-")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2032}", with: "'")
            .replacingOccurrences(of: "`", with: "'")
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parseDutchDate(_ text: String, referenceDate: Date = Date()) -> String? {
        let pattern = #"\b(ma|di|wo|do|vr|za|zo)\s+(\d{1,2})\s+(jan|feb|mrt|mar|apr|mei|may|jun|jul|aug|sep|okt|oct|nov|dec)\b"#
        guard let match = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }
        let token = String(text[match])
        let parts = token.split(separator: " ")
        guard parts.count >= 3,
              let day = Int(parts[1]),
              let month = dutchMonths[String(String(parts[2]).lowercased().prefix(3))] else {
            return nil
        }

        let calendar = Calendar.current
        var year = calendar.component(.year, from: referenceDate)
        var components = DateComponents(year: year, month: month, day: day)
        guard var candidate = calendar.date(from: components) else { return nil }
        if candidate > referenceDate {
            year -= 1
            components.year = year
            candidate = calendar.date(from: components) ?? candidate
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func parseScreenshotText(_ ocrText: String, referenceDate: Date = Date()) -> ParsedScreenshotResult {
        let text = normalizeText(ocrText.replacingOccurrences(of: "\n", with: " "))
        var fieldsFound = 0
        var warnings: [String] = []

        let date = parseDutchDate(text, referenceDate: referenceDate)
        let missingDate = date == nil
        if date != nil { fieldsFound += 1 }

        let durationSec = firstMatch(text, patterns: [
            #"Work[- ]?outtijd\s*Afstand\s*(\d+:\d{2}:\d{2})"#,
            #"Work[- ]?outtijd\s*(\d+:\d{2}:\d{2})"#,
            #"\b(\d+:\d{2}:\d{2})\b"#
        ]).flatMap { SwimFormatters.parseDurationSec($0) }
        if durationSec != nil { fieldsFound += 1 }

        let distanceM = firstMatch(text, patterns: [
            #"\d+:\d{2}:\d{2}\s+([\d.]+\s*M)"#,
            #"Afstand\s*([\d.]+\s*M)"#,
            #"Distance\s*([\d.]+\s*M)"#
        ]).flatMap { parseDistanceToken($0) }
        if distanceM != nil { fieldsFound += 1 }

        var activeKcal: Int?
        var totalKcal: Int?
        if let dual = text.range(of: #"Actieve\s*kilocalorie[ëe]n\s*Totale\s*kilocalorie[ëe]n\s*(\d+)\s*KCAL\s*(\d+)\s*KCAL"#, options: [.regularExpression, .caseInsensitive]) {
            let token = String(text[dual])
            let numbers = token.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
            if numbers.count >= 2 {
                activeKcal = numbers[numbers.count - 2]
                totalKcal = numbers[numbers.count - 1]
            }
        } else {
            activeKcal = firstMatch(text, patterns: [#"Actieve\s*kilocalorie[ëe]n\s*(\d+)"#, #"Active\s*calories\s*(\d+)"#]).flatMap { Int($0) }
            totalKcal = firstMatch(text, patterns: [#"Totale\s*kilocalorie[ëe]n\s*(\d+)"#, #"Total\s*calories\s*(\d+)"#]).flatMap { Int($0) }
        }
        if activeKcal != nil { fieldsFound += 1 }
        if totalKcal != nil { fieldsFound += 1 }

        let paceSecPer100m = firstMatch(text, patterns: [
            #"Gem\.?\s*tempo\s*Gem\.?\s*hartslag\s*(\d+'\d{1,2}")"#,
            #"Gem\.?\s*tempo\s*(\d+'\d{1,2}")"#,
            #"Gem\.?\s*tempo\s*Gem\.?\s*hartslag\s*(\d{2,3}")"#,
            #"(\d+'\d{1,2}")(?:\s*/\s*100\s*m|\s*\d*\s*m)"#,
            #"(\d{2,3}")(?:\s*[n\/]?\d*\s*m|\s*SPM)"#
        ]).flatMap { parseOcrPace($0) }
        if paceSecPer100m != nil { fieldsFound += 1 }

        let avgHeartRate = firstMatch(text, patterns: [#"(\d{2,3})\s*SPM"#, #"Gem\.?\s*hartslag\s*(\d{2,3})"#]).flatMap { Int($0) }
        if avgHeartRate != nil { fieldsFound += 1 }

        var laps: Int?
        var poolLengthM = 25
        if let lapsPool = text.range(of: #"Banen\s*Baanlengte\s*(\d+)\s*(\d+)\s*M"#, options: [.regularExpression, .caseInsensitive]) {
            let token = String(text[lapsPool])
            let numbers = token.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
            if numbers.count >= 2 {
                laps = numbers[numbers.count - 2]
                poolLengthM = numbers[numbers.count - 1]
            }
        } else {
            laps = firstMatch(text, patterns: [#"Banen\s*(\d+)"#, #"Laps\s*(\d+)"#]).flatMap { Int($0) }
            if let pool = firstMatch(text, patterns: [#"Baanlengte\s*(\d+)\s*M"#, #"\b(\d{2})\s*M\s*$"#]).flatMap({ Int($0) }) {
                poolLengthM = pool
            }
        }
        if laps != nil { fieldsFound += 1 }

        let goalM = firstMatch(text, patterns: [#"Doel:\s*([\d.]+)\s*M"#]).flatMap { SwimFormatters.parseDistanceM($0) }
        if goalM != nil { fieldsFound += 1 }

        let timeRange: String
        if let range = text.range(of: #"\b(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})\b"#, options: .regularExpression) {
            let token = String(text[range])
            let parts = token.split(separator: "-").map { String($0).trimmingCharacters(in: .whitespaces) }
            timeRange = parts.count == 2 ? "\(parts[0])–\(parts[1])" : ""
        } else {
            timeRange = ""
        }

        var location = ""
        if text.localizedCaseInsensitiveContains("Tilburg") {
            location = "Tilburg"
        }

        let strokes = StrokeDistances(
            mixedM: parseStrokeDistance(text, label: "Gemengd"),
            breaststrokeM: parseStrokeDistance(text, label: "Schoolslag"),
            freestyleM: parseStrokeDistance(text, label: "Vrije\\s*slag"),
            backstrokeM: parseStrokeDistance(text, label: "Rugslag"),
            butterflyM: parseStrokeDistance(text, label: "Vlinderslag")
        )
        if [strokes.mixedM, strokes.breaststrokeM, strokes.freestyleM, strokes.backstrokeM, strokes.butterflyM].contains(where: { $0 != nil }) {
            fieldsFound += 1
        }

        if distanceM == nil { warnings.append("distance_not_found") }
        if paceSecPer100m == nil { warnings.append("pace_not_found") }
        if missingDate { warnings.append("date_missing") }

        let fields = ParsedScreenshotFields(
            date: date,
            durationSec: durationSec,
            distanceM: distanceM,
            activeKcal: activeKcal,
            totalKcal: totalKcal,
            paceSecPer100m: paceSecPer100m,
            avgHeartRate: avgHeartRate,
            laps: laps,
            poolLengthM: poolLengthM,
            goalM: goalM,
            location: location,
            timeRange: timeRange,
            strokes: strokes
        )

        let detection = detectSwimWorkout(text: text, fields: fields)
        if !detection.isSwimWorkout {
            warnings.append("not_swim_workout")
        }

        let confidence = min(100, Int(round(Double(fieldsFound) / 10.0 * 100.0)))

        return ParsedScreenshotResult(
            fields: fields,
            confidence: confidence,
            missingDate: missingDate,
            warnings: warnings,
            isSwimWorkout: detection.isSwimWorkout,
            detectedSport: detection.detectedSport
        )
    }

    static func fieldsToMetrics(_ fields: ParsedScreenshotFields) -> SwimMetrics {
        SwimMetrics(
            durationSec: fields.durationSec,
            distanceM: fields.distanceM,
            activeKcal: fields.activeKcal,
            totalKcal: fields.totalKcal,
            paceSecPer100m: fields.paceSecPer100m,
            avgHeartRate: fields.avgHeartRate,
            laps: fields.laps,
            poolLengthM: fields.poolLengthM,
            goalM: fields.goalM,
            location: fields.location,
            timeRange: fields.timeRange,
            strokes: fields.strokes
        )
    }

    private static func firstMatch(_ text: String, patterns: [String]) -> String? {
        for pattern in patterns {
            guard let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { continue }
            let match = String(text[range])
            if let capture = captureGroup(from: match, pattern: pattern) {
                return capture
            }
        }
        return nil
    }

    private static func captureGroup(from match: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let nsRange = NSRange(match.startIndex..<match.endIndex, in: match)
        guard let result = regex.firstMatch(in: match, range: nsRange), result.numberOfRanges > 1,
              let range = Range(result.range(at: 1), in: match) else {
            return nil
        }
        return String(match[range])
    }

    private static func parseDistanceToken(_ token: String) -> Int? {
        SwimFormatters.parseDistanceM(token.replacingOccurrences(of: " ", with: ""))
    }

    private static func parseOcrPace(_ raw: String) -> Int? {
        if let direct = SwimFormatters.parsePaceSecPer100m(raw) { return direct }
        if let match = raw.range(of: #"^(\d{2,3})""#, options: .regularExpression) {
            let digits = String(raw[match]).filter(\.isNumber)
            if digits.count == 3 {
                let minutes = Int(String(digits.prefix(1))) ?? 0
                let seconds = Int(String(digits.suffix(2))) ?? 0
                return minutes * 60 + seconds
            }
        }
        return nil
    }

    private static func parseStrokeDistance(_ text: String, label: String) -> Int? {
        let pattern = "\(label)\\s*\\(([\\d.\\s]+)\\s*m\\)"
        guard let match = firstMatch(text, patterns: [pattern]) else { return nil }
        return SwimFormatters.parseDistanceM(match)
    }

    private static func detectSwimWorkout(text: String, fields: ParsedScreenshotFields) -> (isSwimWorkout: Bool, detectedSport: String?) {
        let otherSports: [(String, [String])] = [
            ("run", [#"\bHardlopen\b"#, #"\bIndoor\s*Run\b"#]),
            ("walk", [#"\bWandelen\b"#, #"\bOutdoor\s*Walk\b"#]),
            ("cycle", [#"\bFietsen\b"#, #"\bIndoor\s*Cycling\b"#]),
            ("strength", [#"\bKrachttraining\b"#])
        ]

        for (sport, patterns) in otherSports {
            if patterns.contains(where: { text.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }) {
                return (false, sport)
            }
        }

        var swimSignals = 0
        if text.range(of: #"\bZwem(bad|men)\b"#, options: [.regularExpression, .caseInsensitive]) != nil { swimSignals += 1 }
        if text.range(of: #"\bBanen\b"#, options: .regularExpression) != nil { swimSignals += 1 }
        if text.range(of: #"/\s*100\s*m\b"#, options: .regularExpression) != nil { swimSignals += 1 }
        if fields.paceSecPer100m != nil { swimSignals += 1 }
        if fields.laps != nil { swimSignals += 1 }
        if [fields.strokes.mixedM, fields.strokes.breaststrokeM, fields.strokes.freestyleM, fields.strokes.backstrokeM, fields.strokes.butterflyM].contains(where: { $0 != nil }) {
            swimSignals += 1
        }

        if swimSignals >= 2 {
            return (true, nil)
        }
        return (false, "unknown")
    }
}
