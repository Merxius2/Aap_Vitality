import Foundation
import SwiftUI

struct AppThemeDefinition: Identifiable, Equatable {
    var id: String { code }
    let code: String
    let nameKey: String
    let primary: Color
    let secondary: Color
    let accent: Color
    let previewStyle: String
    let previewFrom: Color
    let previewVia: Color
    let previewTo: Color
    let previewQuaternary: Color?
}

enum AppThemes {
    static let defaultCode = "liquid-os"

    static let all: [AppThemeDefinition] = [
        theme(
            code: "liquid-os",
            nameKey: "settings.themes.liquidOs.name",
            primary: "#3B5BFF",
            secondary: "#7B5BFF",
            accent: "#E85A8C",
            previewStyle: "gradient",
            previewFrom: "#3B5BFF",
            previewVia: "#7B5BFF",
            previewTo: "#E85A8C"
        ),
        theme(
            code: "gen-z",
            nameKey: "settings.themes.genZ.name",
            primary: "#6200EE",
            secondary: "#D4FF00",
            accent: "#FF69B4",
            previewStyle: "flat",
            previewFrom: "#6200EE",
            previewVia: "#D4FF00",
            previewTo: "#FF69B4"
        ),
        theme(
            code: "classic",
            nameKey: "settings.themes.classic.name",
            primary: "#DF0024",
            secondary: "#F3AF00",
            accent: "#008FD6",
            previewStyle: "flat",
            previewFrom: "#DF0024",
            previewVia: "#F3AF00",
            previewTo: "#008FD6",
            previewQuaternary: "#00AB9F"
        ),
        theme(
            code: "olympic-pool",
            nameKey: "settings.themes.olympicPool.name",
            primary: "#0066CC",
            secondary: "#004C99",
            accent: "#F5C518",
            previewStyle: "flat",
            previewFrom: "#F8FAFC",
            previewVia: "#0066CC",
            previewTo: "#F5C518"
        ),
        theme(
            code: "midnight-lane",
            nameKey: "settings.themes.midnightLane.name",
            primary: "#22D3EE",
            secondary: "#0891B2",
            accent: "#0891B2",
            previewStyle: "flat",
            previewFrom: "#070B14",
            previewVia: "#22D3EE",
            previewTo: "#0891B2"
        ),
        theme(
            code: "retro-wave",
            nameKey: "settings.themes.retroWave.name",
            primary: "#FF6EC7",
            secondary: "#9D4EDD",
            accent: "#5CE1E6",
            previewStyle: "flat",
            previewFrom: "#FF6EC7",
            previewVia: "#9D4EDD",
            previewTo: "#5CE1E6"
        ),
        theme(
            code: "tropical-open",
            nameKey: "settings.themes.tropicalOpen.name",
            primary: "#38BDF8",
            secondary: "#0D9488",
            accent: "#FB7185",
            previewStyle: "gradient",
            previewFrom: "#38BDF8",
            previewVia: "#0D9488",
            previewTo: "#FB7185"
        ),
        theme(
            code: "gold-luxe",
            nameKey: "settings.themes.goldLuxe.name",
            primary: "#B45309",
            secondary: "#F5D565",
            accent: "#B45309",
            previewStyle: "flat",
            previewFrom: "#FFF8E7",
            previewVia: "#F5D565",
            previewTo: "#B45309"
        ),
        theme(
            code: "platinum-elite",
            nameKey: "settings.themes.platinumElite.name",
            primary: "#475569",
            secondary: "#CBD5E1",
            accent: "#64748B",
            previewStyle: "flat",
            previewFrom: "#F8FAFC",
            previewVia: "#CBD5E1",
            previewTo: "#64748B",
            previewQuaternary: "#A5B4FC"
        ),
    ]

    static func theme(for code: String) -> AppThemeDefinition {
        all.first { $0.code == code } ?? all[0]
    }

    private static func theme(
        code: String,
        nameKey: String,
        primary: String,
        secondary: String,
        accent: String,
        previewStyle: String,
        previewFrom: String,
        previewVia: String,
        previewTo: String,
        previewQuaternary: String? = nil
    ) -> AppThemeDefinition {
        AppThemeDefinition(
            code: code,
            nameKey: nameKey,
            primary: Color(hex: primary),
            secondary: Color(hex: secondary),
            accent: Color(hex: accent),
            previewStyle: previewStyle,
            previewFrom: Color(hex: previewFrom),
            previewVia: Color(hex: previewVia),
            previewTo: Color(hex: previewTo),
            previewQuaternary: previewQuaternary.map(Color.init(hex:))
        )
    }
}

private struct ThemeColorsKey: EnvironmentKey {
    static let defaultValue = AppThemes.theme(for: AppThemes.defaultCode)
}

extension EnvironmentValues {
    var themeColors: AppThemeDefinition {
        get { self[ThemeColorsKey.self] }
        set { self[ThemeColorsKey.self] = newValue }
    }
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0
            g = 0
            b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}
