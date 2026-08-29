import SwiftUI
import UIKit

private struct AppIsDarkKey: EnvironmentKey {
    static let defaultValue = false
}

private struct AmbientBackgroundVisibleKey: EnvironmentKey {
    static let defaultValue = false
}

private struct AppAnimationsPausedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var appIsDark: Bool {
        get { self[AppIsDarkKey.self] }
        set { self[AppIsDarkKey.self] = newValue }
    }

    var ambientBackgroundVisible: Bool {
        get { self[AmbientBackgroundVisibleKey.self] }
        set { self[AmbientBackgroundVisibleKey.self] = newValue }
    }

    var appAnimationsPaused: Bool {
        get { self[AppAnimationsPausedKey.self] }
        set { self[AppAnimationsPausedKey.self] = newValue }
    }
}

/// Shared low-frequency animation cadence to reduce display-linked battery drain.
enum BatteryEfficientAnimation {
    static let frameInterval: TimeInterval = 1.0 / 20.0

    static var timelineSchedule: PeriodicTimelineSchedule {
        .periodic(from: .now, by: frameInterval)
    }
}

// MARK: - Visual profile model

struct ThemeVisualProfile {
    let displayPrimary: Color
    let displayAccent: Color
    let pageBackground: ThemePageBackground
    let card: ThemeCardStyle
    let tabBar: ThemeTabBarStyle
    let navBar: ThemeNavBarStyle
    let topBar: ThemeTopBarStyle
    let uploadFAB: ThemeUploadFABStyle
}

enum ThemePageBackground {
    case systemGrouped
    case solid(Color)
    case topRadial(glow: Color, base: Color)
    case dualCorner(base: Color, topTrailing: Color, bottomLeading: Color)
    case verticalGradient([Color])
    case tileGrid(base: Color, line: Color, spacing: CGFloat)
}

enum ThemeCardStyle {
    case glass
    case flat(
        fill: Color,
        border: Color,
        borderWidth: CGFloat = 1,
        cornerRadius: CGFloat = 14,
        shadow: Color? = nil,
        shadowY: CGFloat = 2,
        glow: Color? = nil
    )
    case inset(
        fill: Color,
        border: Color,
        cornerRadius: CGFloat = 14
    )
}

enum ThemeTabBarAccentStripePosition {
    case top
    case bottom
}

struct ThemeTabBarStyle {
    let usesSystemDefault: Bool
    let background: Color
    let backgroundGradient: [Color]?
    let selectedColor: Color
    let unselectedColor: Color
    let accentStripe: Color?
    let accentStripePosition: ThemeTabBarAccentStripePosition
    var topCornerRadius: CGFloat = 0
    var borderColor: Color? = nil
    var usesRaisedShadow: Bool = false
    var usesThemeFont: Bool = false
    var fadesUnselectedLabels: Bool = true
    var usesPlainTabIcons: Bool = false
    var tabIconSize: CGFloat = 20
    var fabLabelInactiveColor: Color? = nil
}

struct ThemeNavBarStyle {
    let usesThemeGradient: Bool
    let solidColor: Color?
    let gradient: [Color]?
    let tint: Color
    let lightContent: Bool
    var titleColor: Color? = nil
    var usesThemeFont: Bool = false
    var borderColor: Color? = nil
    var usesRaisedShadow: Bool = false
}

struct ThemeTopBarStyle {
    let background: Color
    let backgroundGradient: [Color]?
    let borderColor: Color
    let borderWidth: CGFloat
    let shadowColor: Color
    let dividerColor: Color
    let coinsColor: Color
    let settingsColor: Color
}

struct ThemeUploadFABStyle {
    let usesOverlay: Bool
    let gradient: [Color]?
    let solid: Color?
    let iconColor: Color
    let borderColor: Color
    var borderWidth: CGFloat = 2
    let shadowColor: Color
    let bottomAccent: Color?
    var usesRaisedShadow: Bool = false
    var usesBorderBottomAccent: Bool = false
}

enum ThemeVisualProfiles {
    static let brandBlue = Color(red: 0.23, green: 0.27, blue: 1.0)
    static let brandBlueDeep = Color(red: 0.16, green: 0.27, blue: 0.8)
    static let brandViolet = Color(red: 0.48, green: 0.36, blue: 1.0)

    private static func glassTopBar(
        background: Color = Color.white.opacity(0.72),
        backgroundGradient: [Color]? = nil,
        borderColor: Color = Color.black.opacity(0.06),
        coinsColor: Color = Color(red: 0.851, green: 0.467, blue: 0.024),
        settingsColor: Color = Color(red: 0.44, green: 0.44, blue: 0.48)
    ) -> ThemeTopBarStyle {
        ThemeTopBarStyle(
            background: background,
            backgroundGradient: backgroundGradient,
            borderColor: borderColor,
            borderWidth: 1,
            shadowColor: Color.black.opacity(0.06),
            dividerColor: Color.black.opacity(0.08),
            coinsColor: coinsColor,
            settingsColor: settingsColor
        )
    }

    static func isAlwaysDark(_ code: String) -> Bool {
        code == "midnight-lane" || code == "retro-wave"
    }

    static func profile(code: String, isDark: Bool) -> ThemeVisualProfile {
        let dark = isAlwaysDark(code) ? true : isDark
        switch code {
        case "gen-z": return genZ(dark)
        case "classic": return classic(dark)
        case "olympic-pool": return olympicPool(dark)
        case "midnight-lane": return midnightLane()
        case "retro-wave": return retroWave()
        case "tropical-open": return tropicalOpen(dark)
        case "gold-luxe": return goldLuxe(dark)
        case "platinum-elite": return platinumElite(dark)
        default: return liquidOS(dark)
        }
    }

    // MARK: liquid-os

    private static func liquidOS(_ dark: Bool) -> ThemeVisualProfile {
        ThemeVisualProfile(
            displayPrimary: brandBlue,
            displayAccent: Color(red: 0.91, green: 0.35, blue: 0.55),
            pageBackground: dark
                ? .topRadial(
                    glow: Color(red: 0.48, green: 0.36, blue: 1.0, opacity: 0.10),
                    base: Color(red: 0.04, green: 0.04, blue: 0.05)
                )
                : .topRadial(
                    glow: Color(red: 0.48, green: 0.36, blue: 1.0, opacity: 0.08),
                    base: Color(red: 0.933, green: 0.945, blue: 0.965)
                ),
            card: .glass,
            tabBar: ThemeTabBarStyle(
                usesSystemDefault: true,
                background: .clear,
                backgroundGradient: nil,
                selectedColor: brandBlueDeep,
                unselectedColor: Color(red: 0.44, green: 0.44, blue: 0.48),
                accentStripe: nil,
                accentStripePosition: .top
            ),
            navBar: ThemeNavBarStyle(
                usesThemeGradient: true,
                solidColor: nil,
                gradient: nil,
                tint: brandBlue,
                lightContent: false
            ),
            topBar: glassTopBar(),
            uploadFAB: ThemeUploadFABStyle(
                usesOverlay: true,
                gradient: [brandBlue, brandViolet],
                solid: nil,
                iconColor: .white,
                borderColor: .white,
                shadowColor: brandBlue.opacity(0.45),
                bottomAccent: nil
            )
        )
    }

    // MARK: gen-z

    private static func genZ(_ dark: Bool) -> ThemeVisualProfile {
        let purple = Color(red: 0.384, green: 0.0, blue: 0.933)
        let lime = Color(red: 0.831, green: 1.0, blue: 0.0)
        return ThemeVisualProfile(
            displayPrimary: purple,
            displayAccent: lime,
            pageBackground: .solid(dark ? Color(red: 0.07, green: 0.03, blue: 0.125) : Color(red: 0.953, green: 0.933, blue: 1.0)),
            card: .flat(
                fill: dark ? Color(red: 0.118, green: 0.063, blue: 0.208) : .white,
                border: dark ? lime.opacity(0.14) : Color(red: 0.384, green: 0.0, blue: 0.933, opacity: 0.12),
                borderWidth: 2,
                cornerRadius: 28,
                shadow: Color(red: 0.384, green: 0.0, blue: 0.933, opacity: dark ? 0.35 : 0.14),
                shadowY: 4
            ),
            tabBar: ThemeTabBarStyle(
                usesSystemDefault: false,
                background: dark ? Color(red: 0.24, green: 0.0, blue: 0.47) : purple,
                backgroundGradient: nil,
                selectedColor: lime,
                unselectedColor: Color.white.opacity(0.88),
                accentStripe: nil,
                accentStripePosition: .top
            ),
            navBar: ThemeNavBarStyle(
                usesThemeGradient: false,
                solidColor: dark ? Color(red: 0.24, green: 0.0, blue: 0.47) : purple,
                gradient: nil,
                tint: lime,
                lightContent: true
            ),
            topBar: glassTopBar(
                background: dark ? Color(red: 0.24, green: 0.0, blue: 0.47) : purple,
                borderColor: Color.black.opacity(0.18),
                coinsColor: lime,
                settingsColor: .white
            ),
            uploadFAB: ThemeUploadFABStyle(
                usesOverlay: true,
                gradient: nil,
                solid: lime,
                iconColor: Color(red: 0.1, green: 0.1, blue: 0.1),
                borderColor: Color.white.opacity(0.35),
                shadowColor: .black.opacity(0.18),
                bottomAccent: nil
            )
        )
    }

    // MARK: classic

    private static func classic(_ dark: Bool) -> ThemeVisualProfile {
        let lightBar = Color(red: 0.0, green: 0.44, blue: 1.0) // #0070FF
        let ink = Color(red: 0.102, green: 0.102, blue: 0.102) // #1A1A1A
        let pageGray = dark
            ? Color(red: 0.227, green: 0.227, blue: 0.227)   // #3A3A3A
            : Color(red: 0.741, green: 0.741, blue: 0.741)   // #BDBDBD
        let navGray = dark
            ? Color(red: 0.145, green: 0.145, blue: 0.145)   // #252525
            : Color(red: 0.557, green: 0.557, blue: 0.557)   // #8E8E8E
        let panel = dark
            ? Color(red: 0.271, green: 0.271, blue: 0.271)   // #454545
            : Color(red: 0.831, green: 0.831, blue: 0.831)   // #D4D4D4
        let fabPanel = Color(red: 0.831, green: 0.831, blue: 0.831) // #D4D4D4 — matches web classic mobile FAB
        return ThemeVisualProfile(
            displayPrimary: Color(red: 0.0, green: 0.56, blue: 0.84), // #008FD6
            displayAccent: lightBar,
            pageBackground: .solid(pageGray),
            card: .inset(
                fill: panel,
                border: dark ? Color.white.opacity(0.08) : Color.black.opacity(0.14),
                cornerRadius: 14
            ),
            tabBar: ThemeTabBarStyle(
                usesSystemDefault: false,
                background: navGray,
                backgroundGradient: nil,
                selectedColor: lightBar,
                unselectedColor: dark ? Color(red: 0.94, green: 0.94, blue: 0.94, opacity: 0.88) : ink,
                accentStripe: lightBar,
                accentStripePosition: .top,
                topCornerRadius: 20,
                borderColor: nil,
                usesRaisedShadow: true,
                usesThemeFont: true,
                fadesUnselectedLabels: false,
                usesPlainTabIcons: true,
                tabIconSize: 17,
                fabLabelInactiveColor: dark
                    ? Color(red: 0.94, green: 0.94, blue: 0.94, opacity: 0.88)
                    : Color(red: 0.176, green: 0.176, blue: 0.176)
            ),
            navBar: ThemeNavBarStyle(
                usesThemeGradient: false,
                solidColor: navGray,
                gradient: nil,
                tint: lightBar,
                lightContent: dark,
                titleColor: dark ? .white : ink,
                usesThemeFont: true,
                borderColor: dark ? Color.white.opacity(0.10) : Color.black.opacity(0.20),
                usesRaisedShadow: true
            ),
            topBar: glassTopBar(),
            uploadFAB: ThemeUploadFABStyle(
                usesOverlay: true,
                gradient: nil,
                solid: fabPanel,
                iconColor: dark ? .white : ink,
                borderColor: .white.opacity(0.9),
                borderWidth: 3,
                shadowColor: .black.opacity(0.14),
                bottomAccent: lightBar,
                usesRaisedShadow: true,
                usesBorderBottomAccent: true
            )
        )
    }

    // MARK: olympic-pool

    private static func olympicPool(_ dark: Bool) -> ThemeVisualProfile {
        let lane = Color(red: 0.0, green: 0.4, blue: 0.8)
        let laneDeep = Color(red: 0.0, green: 0.298, blue: 0.6)
        let gold = Color(red: 0.961, green: 0.773, blue: 0.094)
        return ThemeVisualProfile(
            displayPrimary: lane,
            displayAccent: gold,
            pageBackground: .tileGrid(
                base: dark ? Color(red: 0.043, green: 0.086, blue: 0.157) : Color(red: 0.973, green: 0.98, blue: 0.988),
                line: lane.opacity(dark ? 0.12 : 0.04),
                spacing: 24
            ),
            card: .flat(
                fill: dark ? Color(red: 0.082, green: 0.133, blue: 0.22) : .white,
                border: dark ? lane.opacity(0.35) : lane.opacity(0.18),
                borderWidth: 2,
                cornerRadius: 12,
                shadow: laneDeep.opacity(0.25),
                shadowY: 2
            ),
            tabBar: ThemeTabBarStyle(
                usesSystemDefault: false,
                background: dark ? laneDeep : lane,
                backgroundGradient: nil,
                selectedColor: gold,
                unselectedColor: Color.white.opacity(0.88),
                accentStripe: gold,
                accentStripePosition: .top
            ),
            navBar: ThemeNavBarStyle(
                usesThemeGradient: false,
                solidColor: dark ? laneDeep : lane,
                gradient: nil,
                tint: gold,
                lightContent: true
            ),
            topBar: glassTopBar(),
            uploadFAB: ThemeUploadFABStyle(
                usesOverlay: true,
                gradient: nil,
                solid: gold,
                iconColor: laneDeep,
                borderColor: .white.opacity(0.9),
                shadowColor: gold.opacity(0.45),
                bottomAccent: nil
            )
        )
    }

    // MARK: midnight-lane

    private static func midnightLane() -> ThemeVisualProfile {
        let glow = Color(red: 0.133, green: 0.827, blue: 0.933)
        let panel = Color(red: 0.059, green: 0.09, blue: 0.165)
        return ThemeVisualProfile(
            displayPrimary: glow,
            displayAccent: Color(red: 0.031, green: 0.569, blue: 0.698),
            pageBackground: .topRadial(glow: glow.opacity(0.12), base: Color(red: 0.027, green: 0.043, blue: 0.078)),
            card: .flat(
                fill: panel,
                border: glow.opacity(0.22),
                borderWidth: 1,
                cornerRadius: 14,
                shadow: glow.opacity(0.08),
                shadowY: 0,
                glow: glow.opacity(0.24)
            ),
            tabBar: ThemeTabBarStyle(
                usesSystemDefault: false,
                background: Color(red: 0.031, green: 0.055, blue: 0.11),
                backgroundGradient: nil,
                selectedColor: glow,
                unselectedColor: Color(red: 0.44, green: 0.44, blue: 0.48),
                accentStripe: glow.opacity(0.7),
                accentStripePosition: .top
            ),
            navBar: ThemeNavBarStyle(
                usesThemeGradient: false,
                solidColor: Color(red: 0.031, green: 0.055, blue: 0.11),
                gradient: nil,
                tint: glow,
                lightContent: true
            ),
            topBar: glassTopBar(
                background: Color(red: 0.031, green: 0.055, blue: 0.11),
                borderColor: glow.opacity(0.35),
                coinsColor: glow,
                settingsColor: glow
            ),
            uploadFAB: ThemeUploadFABStyle(
                usesOverlay: true,
                gradient: [brandBlue, brandViolet],
                solid: nil,
                iconColor: .white,
                borderColor: .white,
                shadowColor: brandBlue.opacity(0.45),
                bottomAccent: nil
            )
        )
    }

    // MARK: retro-wave

    private static func retroWave() -> ThemeVisualProfile {
        let pink = Color(red: 1.0, green: 0.431, blue: 0.78)
        let cyan = Color(red: 0.361, green: 0.882, blue: 0.902)
        let panel = Color(red: 0.118, green: 0.039, blue: 0.2)
        return ThemeVisualProfile(
            displayPrimary: pink,
            displayAccent: cyan,
            pageBackground: .verticalGradient([
                Color(red: 0.176, green: 0.106, blue: 0.412),
                Color(red: 0.071, green: 0.024, blue: 0.122),
                Color(red: 0.039, green: 0.016, blue: 0.071),
            ]),
            card: .flat(
                fill: panel,
                border: pink.opacity(0.35),
                borderWidth: 2,
                cornerRadius: 14,
                shadow: Color(red: 0.616, green: 0.306, blue: 0.867, opacity: 0.25),
                shadowY: 0,
                glow: Color(red: 0.616, green: 0.306, blue: 0.867, opacity: 0.18)
            ),
            tabBar: ThemeTabBarStyle(
                usesSystemDefault: false,
                background: Color(red: 0.102, green: 0.039, blue: 0.18),
                backgroundGradient: [Color(red: 0.176, green: 0.106, blue: 0.412), Color(red: 0.102, green: 0.039, blue: 0.18)],
                selectedColor: pink,
                unselectedColor: Color(red: 0.44, green: 0.44, blue: 0.48),
                accentStripe: cyan,
                accentStripePosition: .top
            ),
            navBar: ThemeNavBarStyle(
                usesThemeGradient: true,
                solidColor: nil,
                gradient: [Color(red: 0.176, green: 0.106, blue: 0.412), Color(red: 0.102, green: 0.039, blue: 0.18)],
                tint: pink,
                lightContent: true
            ),
            topBar: glassTopBar(
                background: Color(red: 0.102, green: 0.039, blue: 0.18),
                backgroundGradient: [Color(red: 0.176, green: 0.106, blue: 0.412), Color(red: 0.102, green: 0.039, blue: 0.18)],
                borderColor: pink.opacity(0.45),
                coinsColor: pink,
                settingsColor: pink
            ),
            uploadFAB: ThemeUploadFABStyle(
                usesOverlay: true,
                gradient: [brandBlue, brandViolet],
                solid: nil,
                iconColor: .white,
                borderColor: .white,
                shadowColor: brandBlue.opacity(0.45),
                bottomAccent: nil
            )
        )
    }

    // MARK: tropical-open

    private static func tropicalOpen(_ dark: Bool) -> ThemeVisualProfile {
        let sea = Color(red: 0.051, green: 0.58, blue: 0.533)
        let mint = Color(red: 0.369, green: 0.918, blue: 0.831)
        let coral = Color(red: 0.984, green: 0.443, blue: 0.522)
        return ThemeVisualProfile(
            displayPrimary: dark ? mint : sea,
            displayAccent: coral,
            pageBackground: .dualCorner(
                base: dark ? Color(red: 0.024, green: 0.149, blue: 0.137) : Color(red: 1.0, green: 0.969, blue: 0.929),
                topTrailing: Color(red: 0.22, green: 0.741, blue: 0.973, opacity: dark ? 0.14 : 0.22),
                bottomLeading: coral.opacity(dark ? 0.1 : 0.16)
            ),
            card: .flat(
                fill: dark ? Color(red: 0.059, green: 0.239, blue: 0.22) : Color.white.opacity(0.92),
                border: dark ? mint.opacity(0.22) : sea.opacity(0.2),
                borderWidth: 1,
                cornerRadius: 14,
                shadow: sea.opacity(dark ? 0.35 : 0.1),
                shadowY: 8
            ),
            tabBar: ThemeTabBarStyle(
                usesSystemDefault: false,
                background: dark ? Color(red: 0.059, green: 0.467, blue: 0.431) : sea,
                backgroundGradient: dark
                    ? [Color(red: 0.059, green: 0.467, blue: 0.431), Color(red: 0.024, green: 0.306, blue: 0.231)]
                    : [sea, Color(red: 0.059, green: 0.467, blue: 0.431)],
                selectedColor: mint,
                unselectedColor: Color.white.opacity(0.9),
                accentStripe: nil,
                accentStripePosition: .top
            ),
            navBar: ThemeNavBarStyle(
                usesThemeGradient: true,
                solidColor: nil,
                gradient: dark
                    ? [Color(red: 0.059, green: 0.467, blue: 0.431), Color(red: 0.024, green: 0.306, blue: 0.231)]
                    : [sea, Color(red: 0.059, green: 0.467, blue: 0.431)],
                tint: mint,
                lightContent: true
            ),
            topBar: glassTopBar(),
            uploadFAB: ThemeUploadFABStyle(
                usesOverlay: true,
                gradient: [coral, Color(red: 0.984, green: 0.573, blue: 0.235)],
                solid: nil,
                iconColor: .white,
                borderColor: .white.opacity(0.9),
                shadowColor: coral.opacity(0.45),
                bottomAccent: nil
            )
        )
    }

    // MARK: gold-luxe

    private static func goldLuxe(_ dark: Bool) -> ThemeVisualProfile {
        let gold = Color(red: 0.851, green: 0.467, blue: 0.024)
        let goldLight = Color(red: 0.984, green: 0.749, blue: 0.141)
        let goldDeep = Color(red: 0.573, green: 0.251, blue: 0.055)
        return ThemeVisualProfile(
            displayPrimary: gold,
            displayAccent: goldLight,
            pageBackground: .dualCorner(
                base: dark ? Color(red: 0.102, green: 0.078, blue: 0.031) : Color(red: 1.0, green: 0.973, blue: 0.906),
                topTrailing: goldLight.opacity(dark ? 0.12 : 0.22),
                bottomLeading: Color(red: 0.961, green: 0.62, blue: 0.043, opacity: dark ? 0.08 : 0.14)
            ),
            card: .flat(
                fill: dark ? Color(red: 0.176, green: 0.133, blue: 0.059) : Color(red: 1.0, green: 0.984, blue: 0.922),
                border: gold.opacity(dark ? 0.28 : 0.22),
                borderWidth: 2,
                cornerRadius: 14,
                shadow: goldDeep.opacity(0.25),
                shadowY: 2
            ),
            tabBar: ThemeTabBarStyle(
                usesSystemDefault: false,
                background: dark ? Color(red: 0.271, green: 0.149, blue: 0.012) : goldDeep,
                backgroundGradient: dark
                    ? [Color(red: 0.271, green: 0.149, blue: 0.012), Color(red: 0.169, green: 0.078, blue: 0.004)]
                    : [goldDeep, Color(red: 0.471, green: 0.208, blue: 0.059)],
                selectedColor: goldLight,
                unselectedColor: Color(red: 1.0, green: 0.984, blue: 0.922, opacity: 0.88),
                accentStripe: goldLight,
                accentStripePosition: .top
            ),
            navBar: ThemeNavBarStyle(
                usesThemeGradient: true,
                solidColor: nil,
                gradient: dark
                    ? [Color(red: 0.271, green: 0.149, blue: 0.012), Color(red: 0.169, green: 0.078, blue: 0.004)]
                    : [goldDeep, Color(red: 0.471, green: 0.208, blue: 0.059)],
                tint: goldLight,
                lightContent: true
            ),
            topBar: glassTopBar(),
            uploadFAB: ThemeUploadFABStyle(
                usesOverlay: true,
                gradient: nil,
                solid: goldLight,
                iconColor: goldDeep,
                borderColor: .white.opacity(0.9),
                shadowColor: goldLight.opacity(0.45),
                bottomAccent: nil
            )
        )
    }

    // MARK: platinum-elite

    private static func platinumElite(_ dark: Bool) -> ThemeVisualProfile {
        let ice = Color(red: 0.647, green: 0.706, blue: 0.988)
        let slateDeep = Color(red: 0.278, green: 0.333, blue: 0.412)
        return ThemeVisualProfile(
            displayPrimary: slateDeep,
            displayAccent: ice,
            pageBackground: .dualCorner(
                base: dark ? Color(red: 0.059, green: 0.09, blue: 0.165) : Color(red: 0.945, green: 0.961, blue: 0.976),
                topTrailing: ice.opacity(dark ? 0.1 : 0.18),
                bottomLeading: Color(red: 0.58, green: 0.639, blue: 0.722, opacity: dark ? 0.08 : 0.16)
            ),
            card: .flat(
                fill: dark ? Color(red: 0.118, green: 0.161, blue: 0.231) : Color(red: 0.973, green: 0.98, blue: 0.988),
                border: Color(red: 0.392, green: 0.455, blue: 0.545, opacity: dark ? 0.22 : 0.22),
                borderWidth: 2,
                cornerRadius: 14,
                shadow: slateDeep.opacity(0.25),
                shadowY: 2
            ),
            tabBar: ThemeTabBarStyle(
                usesSystemDefault: false,
                background: dark ? Color(red: 0.118, green: 0.161, blue: 0.231) : Color(red: 0.2, green: 0.255, blue: 0.333),
                backgroundGradient: dark
                    ? [Color(red: 0.118, green: 0.161, blue: 0.231), Color(red: 0.059, green: 0.09, blue: 0.165)]
                    : [Color(red: 0.2, green: 0.255, blue: 0.333), Color(red: 0.118, green: 0.161, blue: 0.231)],
                selectedColor: ice,
                unselectedColor: Color(red: 0.973, green: 0.98, blue: 0.988, opacity: 0.88),
                accentStripe: ice,
                accentStripePosition: .top
            ),
            navBar: ThemeNavBarStyle(
                usesThemeGradient: true,
                solidColor: nil,
                gradient: dark
                    ? [Color(red: 0.118, green: 0.161, blue: 0.231), Color(red: 0.059, green: 0.09, blue: 0.165)]
                    : [Color(red: 0.2, green: 0.255, blue: 0.333), Color(red: 0.118, green: 0.161, blue: 0.231)],
                tint: ice,
                lightContent: true
            ),
            topBar: glassTopBar(),
            uploadFAB: ThemeUploadFABStyle(
                usesOverlay: true,
                gradient: [Color(red: 0.796, green: 0.835, blue: 0.882), Color(red: 0.58, green: 0.639, blue: 0.722)],
                solid: nil,
                iconColor: Color(red: 0.118, green: 0.161, blue: 0.231),
                borderColor: .white.opacity(0.9),
                shadowColor: Color(red: 0.58, green: 0.639, blue: 0.722, opacity: 0.45),
                bottomAccent: nil
            )
        )
    }
}

// MARK: - Page backgrounds

struct ThemedPageBackgroundView: View {
    let background: ThemePageBackground

    var body: some View {
        switch background {
        case .systemGrouped:
            Color(.systemGroupedBackground).ignoresSafeArea()
        case .solid(let color):
            color.ignoresSafeArea()
        case .topRadial(let glow, let base):
            ZStack {
                base
                RadialGradient(
                    colors: [glow, .clear],
                    center: UnitPoint(x: 0.5, y: 0.0),
                    startRadius: 0,
                    endRadius: 420
                )
            }
            .ignoresSafeArea()
        case .dualCorner(let base, let topTrailing, let bottomLeading):
            ZStack {
                base
                RadialGradient(
                    colors: [topTrailing, .clear],
                    center: UnitPoint(x: 1.0, y: 0.0),
                    startRadius: 0,
                    endRadius: 360
                )
                RadialGradient(
                    colors: [bottomLeading, .clear],
                    center: UnitPoint(x: 0.0, y: 1.0),
                    startRadius: 0,
                    endRadius: 320
                )
            }
            .ignoresSafeArea()
        case .verticalGradient(let colors):
            LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        case .tileGrid(let base, let line, let spacing):
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(base))
                var x: CGFloat = 0
                while x <= size.width {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(line), lineWidth: 1)
                    x += spacing
                }
                var y: CGFloat = 0
                while y <= size.height {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(line), lineWidth: 1)
                    y += spacing
                }
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Modifiers

struct ThemedPageBackgroundModifier: ViewModifier {
    @EnvironmentObject private var preferences: UserPreferencesService
    @EnvironmentObject private var viewModel: SwimViewModel
    @Environment(\.appIsDark) private var appIsDark
    @Environment(\.ambientBackgroundVisible) private var ambientBackgroundVisible

    func body(content: Content) -> some View {
        content
            // Hide Form/List system fill so this SwiftUI backdrop (theme or wallpaper) shows through.
            .scrollContentBackground(ambientBackgroundVisible ? .hidden : .automatic)
            .background {
                AppBackdropView(
                    themeCode: preferences.themeCode,
                    isDark: appIsDark,
                    activeWallpaper: viewModel.profile.activeWallpaper,
                    activeAmbient: viewModel.profile.activeAmbient
                )
                .id(
                    "\(viewModel.profile.activeWallpaper ?? "none")|"
                        + "\(viewModel.profile.activeAmbient ?? "none")|"
                        + "\(preferences.themeCode)"
                )
            }
    }
}

struct ThemedCardModifier: ViewModifier {
    @EnvironmentObject private var preferences: UserPreferencesService
    @Environment(\.appIsDark) private var appIsDark

    private var profile: ThemeVisualProfile {
        ThemeVisualProfiles.profile(
            code: preferences.themeCode,
            isDark: appIsDark
        )
    }

    func body(content: Content) -> some View {
        switch profile.card {
        case .glass:
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
        case .flat(let fill, let border, let borderWidth, let cornerRadius, let shadow, let shadowY, _):
            content
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(fill)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(border, lineWidth: borderWidth)
                        )
                        .shadow(color: shadow ?? .clear, radius: 8, y: shadowY)
                }
        case .inset(let fill, let border, let cornerRadius):
            content
                .background(fill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(border, lineWidth: 1)
                )
        }
    }
}

struct ThemedNavBarConfigurator: UIViewControllerRepresentable {
    let style: ThemeNavBarStyle
    let themeCode: String

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()

        if let gradient = style.gradient,
           let image = UIImage.themeGradient(colors: gradient.map(UIColor.init)) {
            appearance.backgroundColor = .clear
            appearance.backgroundImage = image
        } else if let solid = style.solidColor {
            appearance.backgroundColor = UIColor(solid)
        }

        if style.usesRaisedShadow {
            appearance.shadowColor = UIColor.black.withAlphaComponent(0.14)
            appearance.shadowImage = nil
        } else if let border = style.borderColor {
            appearance.shadowColor = UIColor(border)
            appearance.shadowImage = nil
        } else {
            appearance.shadowColor = .clear
            appearance.shadowImage = UIImage()
        }

        var titleAttributes: [NSAttributedString.Key: Any] = [:]
        if let titleColor = style.titleColor {
            titleAttributes[.foregroundColor] = UIColor(titleColor)
        }
        if style.usesThemeFont {
            titleAttributes[.font] = ThemeTypography.uiFont(
                for: themeCode,
                textStyle: .headline,
                weight: .semibold
            )
        }
        appearance.titleTextAttributes = titleAttributes
        appearance.largeTitleTextAttributes = titleAttributes

        let navBar = UINavigationBar.appearance()
        navBar.standardAppearance = appearance
        navBar.scrollEdgeAppearance = appearance
        navBar.compactAppearance = appearance
        navBar.tintColor = UIColor(style.tint)
    }
}

struct ThemedTabBarConfigurator: UIViewControllerRepresentable {
    let profile: ThemeVisualProfile

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        let appearance = UITabBarAppearance()
        if profile.tabBar.usesSystemDefault {
            appearance.configureWithDefaultBackground()
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
            UITabBar.appearance().tintColor = UIColor(profile.tabBar.selectedColor)
            UITabBar.appearance().unselectedItemTintColor = UIColor(profile.tabBar.unselectedColor)
            return
        }

        appearance.configureWithOpaqueBackground()
        if let gradient = profile.tabBar.backgroundGradient {
            let colors = gradient.map { UIColor($0) }
            if let image = UIImage.themeGradient(colors: colors) {
                appearance.backgroundImage = image
                appearance.backgroundColor = .clear
            } else {
                appearance.backgroundColor = UIColor(profile.tabBar.background)
            }
        } else {
            appearance.backgroundColor = UIColor(profile.tabBar.background)
        }
        appearance.shadowImage = UIImage()
        if let stripe = profile.tabBar.accentStripe {
            appearance.shadowColor = UIColor(stripe)
        }

        let normal = appearance.stackedLayoutAppearance.normal
        normal.iconColor = UIColor(profile.tabBar.unselectedColor)
        normal.titleTextAttributes = [
            .foregroundColor: UIColor(profile.tabBar.unselectedColor),
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
        ]

        let selected = appearance.stackedLayoutAppearance.selected
        selected.iconColor = UIColor(profile.tabBar.selectedColor)
        selected.titleTextAttributes = [
            .foregroundColor: UIColor(profile.tabBar.selectedColor),
            .font: UIFont.systemFont(ofSize: 10, weight: .bold),
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = UIColor(profile.tabBar.selectedColor)
        UITabBar.appearance().unselectedItemTintColor = UIColor(profile.tabBar.unselectedColor)
    }
}

struct ThemedUploadFAB: View {
    let style: ThemeUploadFABStyle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(style.iconColor)
                .frame(width: 58, height: 58)
                .background {
                    Circle().fill(fabFill)
                }
                .overlay(
                    Circle()
                        .strokeBorder(style.borderColor, lineWidth: style.borderWidth)
                )
                .shadow(color: style.shadowColor, radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Upload")
    }

    private var fabFill: AnyShapeStyle {
        if let gradient = style.gradient, gradient.count >= 2 {
            AnyShapeStyle(
                LinearGradient(
                    colors: gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else if let solid = style.solid {
            AnyShapeStyle(solid)
        } else {
            AnyShapeStyle(Color("BrandBlue"))
        }
    }
}

struct ThemeTabBarChrome: View {
    let accentStripe: Color?

    var body: some View {
        if let accentStripe {
            Rectangle()
                .fill(accentStripe)
                .frame(height: 4)
                .frame(maxWidth: .infinity)
                .offset(y: 28)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - View extensions

extension View {
    func themedPageBackground() -> some View {
        modifier(ThemedPageBackgroundModifier())
    }

    func themedCard() -> some View {
        modifier(ThemedCardModifier())
    }

    /// Keeps grouped Form rows readable over wallpaper/vibes without per-row rounded pills.
    func themedListRowBackground() -> some View {
        modifier(ThemedListRowBackgroundModifier())
    }
}

private struct ThemedListRowBackgroundModifier: ViewModifier {
    @Environment(\.ambientBackgroundVisible) private var ambientBackgroundVisible

    func body(content: Content) -> some View {
        if ambientBackgroundVisible {
            content.listRowBackground(Rectangle().fill(.thinMaterial))
        } else {
            content
        }
    }
}

extension AppThemeDefinition {
    var displayPrimary: Color {
        ThemeVisualProfiles.profile(code: code, isDark: false).displayPrimary
    }

    var displayAccent: Color {
        ThemeVisualProfiles.profile(code: code, isDark: false).displayAccent
    }
}

// MARK: - UIKit helpers

private extension UIImage {
    static func themeGradient(colors: [UIColor], size: CGSize = CGSize(width: 400, height: 88)) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cgColors = colors.map(\.cgColor) as CFArray
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: cgColors,
                locations: nil
            ) else { return }
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
        }
    }
}
