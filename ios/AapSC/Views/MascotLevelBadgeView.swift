import SwiftUI

struct MascotLevelBadgeView: View {
    @EnvironmentObject private var preferences: UserPreferencesService
    let level: String

    var body: some View {
        let meta = MascotPresentation.levelMeta(for: level)

        HStack(spacing: 6) {
            Image(systemName: "water.waves")
                .font(.system(size: 11, weight: .bold))
            Text(preferences.t(meta.labelKey))
                .font(.system(size: 11, weight: .bold))
                .textCase(.uppercase)
        }
        .foregroundStyle(foregroundColor(for: meta.accent))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(backgroundColor(for: meta.accent), in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(borderColor(for: meta.accent), lineWidth: 1)
        )
    }

    private func foregroundColor(for accent: MascotLevelAccent) -> Color {
        switch accent {
        case .emerald: return Color(red: 0.02, green: 0.37, blue: 0.27)
        case .brand: return Color(red: 0.16, green: 0.27, blue: 0.8)
        case .violet: return Color(red: 0.38, green: 0.11, blue: 0.57)
        }
    }

    private func backgroundColor(for accent: MascotLevelAccent) -> Color {
        switch accent {
        case .emerald: return Color(red: 0.82, green: 0.98, blue: 0.9)
        case .brand: return Color(red: 0.88, green: 0.91, blue: 1.0)
        case .violet: return Color(red: 0.93, green: 0.91, blue: 0.99)
        }
    }

    private func borderColor(for accent: MascotLevelAccent) -> Color {
        switch accent {
        case .emerald: return Color(red: 0.65, green: 0.95, blue: 0.82)
        case .brand: return Color(red: 0.75, green: 0.8, blue: 0.98)
        case .violet: return Color(red: 0.82, green: 0.71, blue: 0.96)
        }
    }
}
