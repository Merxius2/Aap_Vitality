import Foundation

enum FeedbackVariants {
    static func pickVariantKey(_ baseKey: String, count: Int, seed: String) -> String {
        guard count > 1 else { return baseKey }
        let idx = abs(seed.hashValue) % count
        return idx == 0 ? baseKey : "\(baseKey)\(idx + 1)"
    }

    static func translateVariant(
        _ t: TranslationService,
        baseKey: String,
        count: Int,
        seed: String,
        params: [String: String] = [:]
    ) -> String {
        let key = pickVariantKey(baseKey, count: count, seed: seed)
        let text = t.t(key, params: params)
        if text == key {
            return t.t(baseKey, params: params)
        }
        return text
    }
}

enum InsightPolarity {
    private static let negativePattern = #"\b(slower|shorter|under goal|under your|dipped a little|critical|below your standard|langzamer|korter|onder je|yavaş|медленнее|-\d+%)\b"#

    private static let positivePattern = #"\b(faster|sneller|longer|langer|record|streak|reeks|быстрее|hızlı|daha hızlı|improv|percentile|personal best|hit your|over your|above|trending faster|trend improv|calories burned|sustained output|sessions in the last)\b"#

    private static let positiveLowerPattern = #"\b(lower|lager)\b"#

    static func isPositiveInsight(_ insight: String) -> Bool {
        let trimmed = insight.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if matches(trimmed, pattern: negativePattern) { return false }
        if matches(trimmed, pattern: positivePattern) { return true }
        if matches(trimmed, pattern: positiveLowerPattern) && !matches(trimmed, pattern: #"\bslow"#) {
            return true
        }
        if matches(trimmed, pattern: #"\b(over|boven)\b"#) && matches(trimmed, pattern: #"\b(goal|doel)\b"#) {
            return true
        }
        return false
    }

    private static func matches(_ text: String, pattern: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
