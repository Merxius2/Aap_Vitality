import SwiftUI

enum MedalIconGlyphs {
    static func label(for id: String) -> String? {
        switch id {
        case "ten_sessions": return "10"
        case "twenty_five_sessions": return "25"
        case "fifty_sessions": return "50"
        case "ten_k_lifetime": return "10K"
        case "fifty_k_lifetime": return "50K"
        case "hundred_k_lifetime": return "100K"
        case "two_hundred_k": return "200K"
        case "two_k_session": return "2K"
        case "two_five_k_session": return "2.5K"
        case "three_k_session": return "3K"
        case "century_laps": return "100"
        case "four_sessions_week": return "4×"
        case "hat_trick": return "3×"
        case "five_k_week": return "5K"
        case "week_warrior": return "7d"
        case "fortnight_flow": return "14d"
        case "eight_sessions_month": return "8"
        case "ten_k_month": return "10K"
        case "twenty_k_month": return "20K"
        case "january_jolt": return "JAN"
        case "sub_200_pace": return "2:00"
        case "sub_210_pace": return "2:10"
        default: return nil
        }
    }

    static func symbol(for id: String) -> String {
        switch id {
        case "first_splash", "double_dip": return "drop.fill"
        case "lap_legend": return "plus.circle"
        case "calorie_collector", "furnace", "ten_k_cal_month": return "flame.fill"
        case "marathon_session": return "figure.pool.swim"
        case "pulse_racer": return "waveform.path.ecg"
        case "goal_crusher": return "checkmark.circle.fill"
        case "frog_master": return "figure.wave"
        case "season_summer": return "sun.max.fill"
        case "season_winter": return "snowflake"
        case "season_spring": return "leaf.fill"
        case "season_autumn": return "wind"
        case "early_bird": return "sunrise.fill"
        case "night_owl": return "moon.stars.fill"
        case "comeback": return "arrow.uturn.up.circle.fill"
        case "holiday_splash": return "star.fill"
        default: return "star.fill"
        }
    }

    static func symbolColor(for id: String) -> Color {
        switch id {
        case "first_splash", "double_dip": return .blue
        case "calorie_collector", "furnace", "ten_k_cal_month", "pulse_racer": return .red
        case "goal_crusher": return .green
        case "frog_master": return .green
        case "season_summer", "early_bird": return .yellow
        case "season_winter", "night_owl": return .indigo
        case "season_spring": return .pink
        case "season_autumn", "hat_trick", "week_warrior", "fortnight_flow": return .orange
        case "comeback": return .green
        case "holiday_splash": return .red
        default: return .white
        }
    }
}

struct MedalGlyphView: View {
    let id: String
    let earned: Bool
    var size: CGFloat = 28

    var body: some View {
        if let label = MedalIconGlyphs.label(for: id) {
            Text(label)
                .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                .foregroundStyle(earned ? .white : Color(.systemGray))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        } else {
            Image(systemName: MedalIconGlyphs.symbol(for: id))
                .font(.system(size: size * 0.55, weight: .semibold))
                .foregroundStyle(earned ? MedalIconGlyphs.symbolColor(for: id) : Color(.systemGray))
        }
    }

    private var fontSize: CGFloat {
        let len = MedalIconGlyphs.label(for: id)?.count ?? 1
        if len >= 4 { return size * 0.28 }
        if len >= 3 { return size * 0.32 }
        return size * 0.38
    }
}

struct MedalTierPalette {
    let from: Color
    let to: Color
    let rim: Color
    let ribbon: Color

    static func palette(for tier: String) -> MedalTierPalette {
        switch tier {
        case "gold":
            return MedalTierPalette(
                from: Color(red: 0.792, green: 0.541, blue: 0.016),
                to: Color(red: 0.992, green: 0.878, blue: 0.278),
                rim: Color(red: 0.631, green: 0.384, blue: 0.027),
                ribbon: Color(red: 0.918, green: 0.702, blue: 0.031)
            )
        case "silver":
            return MedalTierPalette(
                from: Color(red: 0.420, green: 0.447, blue: 0.502),
                to: Color(red: 0.898, green: 0.906, blue: 0.922),
                rim: Color(red: 0.294, green: 0.333, blue: 0.388),
                ribbon: Color(red: 0.612, green: 0.639, blue: 0.686)
            )
        default:
            return MedalTierPalette(
                from: Color(red: 0.573, green: 0.251, blue: 0.055),
                to: Color(red: 0.961, green: 0.620, blue: 0.043),
                rim: Color(red: 0.471, green: 0.208, blue: 0.059),
                ribbon: Color(red: 0.706, green: 0.325, blue: 0.035)
            )
        }
    }
}
