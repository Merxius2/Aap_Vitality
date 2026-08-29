import Foundation
@testable import AapSC

enum TestFixtures {
    static let profile = SwimProfile(
        name: "",
        sex: "male",
        age: 30,
        mascotId: "flip",
        mascotSwitchMonthKey: nil,
        aiApiKey: "",
        activeAmbient: nil
    )

    static func session(
        id: String,
        date: String,
        metrics: SwimMetrics,
        excludeFromStats: Bool = false
    ) -> SwimSession {
        SwimSession(
            id: id,
            date: date,
            metrics: metrics,
            excludeFromStats: excludeFromStats
        )
    }

    static func session(
        date: String,
        metrics: SwimMetrics
    ) -> SwimSession {
        session(id: date, date: date, metrics: metrics)
    }

    static func metrics(
        distanceM: Int? = nil,
        durationSec: Int? = nil,
        paceSecPer100m: Int? = nil,
        activeKcal: Int? = nil,
        laps: Int? = nil,
        timeRange: String = ""
    ) -> SwimMetrics {
        SwimMetrics(
            durationSec: durationSec,
            distanceM: distanceM,
            activeKcal: activeKcal,
            totalKcal: nil,
            paceSecPer100m: paceSecPer100m,
            avgHeartRate: nil,
            laps: laps,
            poolLengthM: 25,
            goalM: nil,
            location: "",
            timeRange: timeRange,
            strokes: .empty
        )
    }

    static func makeSession(date: String, paceSecPer100m: Int, extra: SwimMetrics? = nil) -> SwimSession {
        var m = extra ?? metrics(distanceM: 3000, activeKcal: 600, durationSec: 1200)
        m.paceSecPer100m = paceSecPer100m
        return session(id: "s-\(date)", date: date, metrics: m)
    }

    static func baseData() -> SwimData {
        SwimData.empty
    }

    static func identityTranslator() -> TranslationService {
        let t = TranslationService()
        t.returnsKeysForTesting = true
        return t
    }

    static let ocrJun3 = """
    wo 3 jun
    Zwembad
    Doel: 2.500 M
    Gemengd (50 m)
    Schoolslag (475 m)
    Vrije slag (2.025 m)
    11:07-12:01
    Tilburg
    Work-outtijd
    0:54:27
    Afstand
    2.550 M
    Actieve kilocalorieën
    573 KCAL
    Totale kilocalorieën
    680 KCAL
    Gem. tempo
    2'10" /100m
    Gem. hartslag
    140 SPM
    Banen
    102
    Baanlengte
    25 M
    """

    static let ocrJun8 = """
    ma 8 jun
    Zwembad
    Doel: 2.500 M
    Gemengd (25 m)
    Schoolslag (250 m)
    Vrije slag (2.225 m)
    10:50-11:41
    Tilburg
    Work-outtijd 0:51:15
    Afstand 2.500 M
    Actieve kilocalorieën 547 KCAL
    Totale kilocalorieën 648 KCAL
    Gem. tempo 2'03" /100m
    Gem. hartslag 143 SPM
    Banen 100
    Baanlengte 25 M
    """

    static let ocrNoDate = """
    Zwembad
    Doel: 2.500 M
    Gemengd (50 m)
    Schoolslag (1.200 m)
    Vrije slag (1.425 m)
    11:33-12:27
    Tilburg
    Work-outtijd 0:53:29
    Afstand 2.675 M
    Actieve kilocalorieën 575 KCAL
    Totale kilocalorieën 679 KCAL
    Gem. tempo 2'00" /100m
    Gem. hartslag 144 SPM
    Banen 107
    Baanlengte 25 M
    """

    static let sampleImportData: SwimData = {
        var data = SwimData.empty
        data.profile = SwimProfile(
            name: "",
            sex: "male",
            age: 35,
            mascotId: nil,
            mascotSwitchMonthKey: nil,
            aiApiKey: "",
            activeAmbient: nil
        )
        data.sessions = [
            SwimSession(
                id: "test-1",
                createdAt: "2025-06-03T12:00:00.000Z",
                date: "2025-06-03",
                metrics: SwimMetrics(
                    durationSec: 3267,
                    distanceM: 2550,
                    activeKcal: 573,
                    totalKcal: 680,
                    paceSecPer100m: 130,
                    avgHeartRate: 140,
                    laps: 102,
                    poolLengthM: 25,
                    goalM: 2500,
                    location: "Tilburg",
                    timeRange: "11:07–12:01",
                    strokes: StrokeDistances(mixedM: 50, breaststrokeM: 475, freestyleM: 2025)
                )
            )
        ]
        return data
    }()
}
