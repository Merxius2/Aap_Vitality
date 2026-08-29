import Foundation

struct MascotGameplay: Equatable {
    var challengeIntensity: Double
    var coinMultiplier: Double
    var minSessionCoins: Int?
    var sessionPenalty: Bool
    var requiredMonthlyTier: String?
    var monthlyPenaltyCoins: Int
    var freeMonthlyRerolls: Int
    var positiveOnly: Bool
    var doubleImprovementBonus: Bool
}

struct MascotDefinition: Equatable {
    var id: String
    var coachedLevel: String
    var aiPersonality: String
    var gameplay: MascotGameplay
}

enum MascotConstants {
    static let ids = ["flip", "flo", "fins"]

    static let flip = MascotDefinition(
        id: "flip",
        coachedLevel: "beginner",
        aiPersonality: "encouraging and approachable — celebrates effort, keeps things light, always positive, never criticises",
        gameplay: MascotGameplay(
            challengeIntensity: 0.75,
            coinMultiplier: 0.5,
            minSessionCoins: 3,
            sessionPenalty: false,
            requiredMonthlyTier: nil,
            monthlyPenaltyCoins: 0,
            freeMonthlyRerolls: 1,
            positiveOnly: true,
            doubleImprovementBonus: false
        )
    )

    static let flo = MascotDefinition(
        id: "flo",
        coachedLevel: "intermediate",
        aiPersonality: "friendly and motivating — warm and enthusiastic, cheers milestones, but honestly points out when statistics decline",
        gameplay: MascotGameplay(
            challengeIntensity: 1,
            coinMultiplier: 1,
            minSessionCoins: 5,
            sessionPenalty: false,
            requiredMonthlyTier: "silver",
            monthlyPenaltyCoins: 40,
            freeMonthlyRerolls: 1,
            positiveOnly: false,
            doubleImprovementBonus: false
        )
    )

    static let fins = MascotDefinition(
        id: "fins",
        coachedLevel: "advanced",
        aiPersonality: "focused and challenging — a demanding performance coach who is direct, critical but fair, always pushes for measurable improvement and calls out slacking",
        gameplay: MascotGameplay(
            challengeIntensity: 1.25,
            coinMultiplier: 1,
            minSessionCoins: nil,
            sessionPenalty: true,
            requiredMonthlyTier: "gold",
            monthlyPenaltyCoins: 75,
            freeMonthlyRerolls: 2,
            positiveOnly: false,
            doubleImprovementBonus: true
        )
    )

    static func mascot(_ id: String?) -> MascotDefinition {
        switch id {
        case "flo": return flo
        case "fins": return fins
        default: return flip
        }
    }

    static func displayName(_ id: String?, t: TranslationService) -> String {
        switch id {
        case "flo": return t.t("settings.mascotFloName")
        case "fins": return t.t("settings.mascotFinsName")
        default: return t.t("settings.mascotFlipName")
        }
    }

    static func cheerKey(_ id: String?) -> String {
        switch id {
        case "flo": return "mascot.cheerFlo"
        case "fins": return "mascot.cheerFins"
        default: return "mascot.cheerFlip"
        }
    }

    static func displayName(_ id: String?) -> String {
        switch id {
        case "flo": return "Flo"
        case "fins": return "Fins"
        default: return "Flip"
        }
    }

    static func aspectRatio(_ id: String?) -> CGFloat {
        switch id {
        case "flo": return 593.0 / 900.0
        case "fins": return 490.0 / 900.0
        default: return 490.0 / 900.0
        }
    }

    static func openImageName(_ id: String?) -> String {
        switch id {
        case "flo": return "MascotFloOpen"
        case "fins": return "MascotFinsOpen"
        default: return "MascotFlipOpen"
        }
    }

    static func closedImageName(_ id: String?) -> String {
        switch id {
        case "flo": return "MascotFloClosed"
        case "fins": return "MascotFinsClosed"
        default: return "MascotFlipClosed"
        }
    }

    static func disappointedOpenImageName(_ id: String?) -> String? {
        switch id {
        case "flo": return "MascotFloDisappointedOpen"
        case "fins": return "MascotFinsDisappointedOpen"
        default: return nil
        }
    }

    static func disappointedClosedImageName(_ id: String?) -> String? {
        switch id {
        case "flo": return "MascotFloClosed"
        case "fins": return "MascotFinsDisappointedClosed"
        default: return nil
        }
    }

    static func previewKey(_ id: String?) -> String {
        switch id {
        case "flo": return "settings.mascotPreviewFlo"
        case "fins": return "settings.mascotPreviewFins"
        default: return "settings.mascotPreviewFlip"
        }
    }

    static func gameplay(_ id: String?) -> MascotGameplay {
        mascot(id).gameplay
    }

    static func coachedLevel(_ id: String?) -> String {
        mascot(id).coachedLevel
    }

    static func nameKey(_ id: String?) -> String {
        switch id {
        case "flo": return "settings.mascotFloName"
        case "fins": return "settings.mascotFinsName"
        default: return "settings.mascotFlipName"
        }
    }

    static func descKey(_ id: String?) -> String {
        switch id {
        case "flo": return "settings.mascotFloDesc"
        case "fins": return "settings.mascotFinsDesc"
        default: return "settings.mascotFlipDesc"
        }
    }

    static func rulesKey(_ id: String?) -> String {
        switch id {
        case "flo": return "settings.mascotFloRules"
        case "fins": return "settings.mascotFinsRules"
        default: return "settings.mascotFlipRules"
        }
    }

    static func traitKeys(_ id: String?) -> [String] {
        switch id {
        case "flo": return ["mascot.traits.friendly", "mascot.traits.motivating"]
        case "fins": return ["mascot.traits.focused", "mascot.traits.challenging"]
        default: return ["mascot.traits.encouraging", "mascot.traits.approachable"]
        }
    }

    static func stageBackgroundImageName(_ id: String?) -> String? {
        switch id {
        case "flo": return "MascotFloStageBg"
        case "fins": return "MascotFinsStageBg"
        default: return "MascotFlipStageBg"
        }
    }
}
