import Foundation

enum AiCoachService {
    struct AiFeedback: Equatable {
        var coachMessage: String
        var motivation: String
        var aiEnhanced: Bool
    }

    static func fetchFeedback(
        apiKey: String,
        language: String,
        profile: SwimProfile,
        session: SwimSession,
        sessions: [SwimSession],
        localFeedback: SessionFeedbackSummary,
        mascotId: String
    ) async throws -> AiFeedback {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw AiCoachError.missingKey }

        let coachName = mascotId.prefix(1).uppercased() + mascotId.dropFirst()
        let personality = MascotConstants.mascot(mascotId).aiPersonality
        let langName = languageName(language)
        let combined = SwimAnalysis.combinedStats(sessions)
        let recent = sessions.suffix(6).dropLast().map { session in
            [
                "date": session.date,
                "distanceM": session.metrics.distanceM as Any,
                "paceSecPer100m": session.metrics.paceSecPer100m as Any,
                "activeKcal": session.metrics.activeKcal as Any,
            ] as [String: Any]
        }

        let systemPrompt = """
        You are \(coachName), a swim coach monkey mascot in a personal training app called Aap-SC.
        Your coaching personality: \(personality).
        Stay fully in that personality in both analysis and motivation.
        Write in \(langName). Be concise and human — like a coach who knows the swimmer personally.
        Avoid bullet lists. Use 2 short paragraphs max: one personal analysis, one motivational closing.
        Reference specific numbers from the data. Do not invent metrics not provided.
        """

        let userPrompt = """
        Swimmer profile: \(profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "unknown name" : profile.name), \(profile.sex) sex, age \(profile.age).
        Address the swimmer by name when you know it.

        Latest session (\(session.date)):
        - Distance: \(session.metrics.distanceM ?? 0) m
        - Duration: \(session.metrics.durationSec ?? 0) sec
        - Pace: \(session.metrics.paceSecPer100m ?? 0) sec/100m
        - Heart rate: \(session.metrics.avgHeartRate ?? 0) bpm
        - Active calories: \(session.metrics.activeKcal ?? 0)
        - Goal: \(session.metrics.goalM.map(String.init) ?? "none") m
        - Laps: \(session.metrics.laps ?? 0)

        Recent sessions: \(jsonString(recent))
        All-time combined: \(jsonString(combined.map(combinedPayload) ?? [:]))
        On-device insights already shown: \(jsonString(localFeedback.insights))
        Badges earned: \(jsonString(localFeedback.badges))

        Give personalised coach feedback and motivation.
        """

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt],
            ],
            "max_tokens": 350,
            "temperature": 0.8,
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AiCoachError.requestFailed }

        if http.statusCode != 200 {
            if let err = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = err["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AiCoachError.api(message)
            }
            throw AiCoachError.api("OpenAI error \(http.statusCode)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AiCoachError.emptyResponse
        }

        let parts = content.components(separatedBy: "\n\n").filter { !$0.isEmpty }
        return AiFeedback(
            coachMessage: parts.first ?? content,
            motivation: parts.count > 1 ? parts[1] : "",
            aiEnhanced: true
        )
    }

    enum AiCoachError: LocalizedError {
        case missingKey
        case requestFailed
        case emptyResponse
        case api(String)

        var errorDescription: String? {
            switch self {
            case .missingKey: return "API key required"
            case .requestFailed: return "AI request failed"
            case .emptyResponse: return "Empty AI response"
            case .api(let message): return message
            }
        }
    }

    private static func languageName(_ code: String) -> String {
        switch code {
        case "nl": return "Dutch"
        case "ru": return "Russian"
        case "tr": return "Turkish"
        default: return "English"
        }
    }

    private static func jsonString(_ value: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value),
              let str = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return str
    }

    private static func combinedPayload(_ stats: CombinedStats) -> [String: Any] {
        [
            "sessionCount": stats.sessionCount,
            "totalDistanceM": stats.totalDistanceM,
            "totalDurationSec": stats.totalDurationSec,
            "avgPaceSecPer100m": stats.avgPaceSecPer100m as Any,
        ]
    }
}
