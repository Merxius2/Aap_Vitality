import SwiftUI

/// Shared layout metrics for the bottom tab bar and upload FAB across all themes.
enum TabBarLayout {
    static let barContentHeight: CGFloat = 52
    static let bottomPadding: CGFloat = 8
    static let horizontalPadding: CGFloat = 8
    static let itemSpacing: CGFloat = 4
    static let iconSize: CGFloat = 20
    static let labelHeight: CGFloat = 11
    static let fabDiameter: CGFloat = 56
    static let fabIconSize: CGFloat = 26
    static let fabSeatInset: CGFloat = 12
    static let bottomStripeHeight: CGFloat = 3
    static let topStripeHeight: CGFloat = 4
    static let classicFabLift: CGFloat = 20

    /// Outline symbols for classic PlayStation (matches web `MobileNav.js`).
    private static let classicProgressIcon = "chart.bar"
    private static let classicMedalsIcon = "medal"
    private static let classicBenchmarkIcon = "chart.line.uptrend.xyaxis"
    private static let classicHistoryIcon = "clock.arrow.circlepath"

    /// Filled symbols used by the other iOS themes.
    private static let themedSettingsIcon = "gearshape.fill"
    private static let classicSettingsIcon = "gearshape"
    private static let themedProgressIcon = "chart.bar.fill"
    private static let themedMedalsIcon = "checkmark.seal.fill"
    private static let themedBenchmarkIcon = "waveform.path.ecg"
    private static let themedHistoryIcon = "clock.arrow.circlepath"

    static func settingsIcon(for tabBar: ThemeTabBarStyle) -> String {
        tabBar.usesPlainTabIcons ? classicSettingsIcon : themedSettingsIcon
    }

    static func progressIcon(for tabBar: ThemeTabBarStyle) -> String {
        tabBar.usesPlainTabIcons ? classicProgressIcon : themedProgressIcon
    }

    static func medalsIcon(for tabBar: ThemeTabBarStyle) -> String {
        tabBar.usesPlainTabIcons ? classicMedalsIcon : themedMedalsIcon
    }

    static func benchmarkIcon(for tabBar: ThemeTabBarStyle) -> String {
        tabBar.usesPlainTabIcons ? classicBenchmarkIcon : themedBenchmarkIcon
    }

    static func historyIcon(for tabBar: ThemeTabBarStyle) -> String {
        tabBar.usesPlainTabIcons ? classicHistoryIcon : themedHistoryIcon
    }

    static func totalHeight(for tabBar: ThemeTabBarStyle) -> CGFloat {
        let stripe = tabBar.accentStripe == nil ? 0
            : (tabBar.accentStripePosition == .bottom ? bottomStripeHeight : topStripeHeight)
        return barContentHeight + stripe
    }

    static func iconSize(for tabBar: ThemeTabBarStyle) -> CGFloat {
        tabBar.usesPlainTabIcons ? tabBar.tabIconSize : iconSize
    }
}

struct CustomTabBar: View {
    @EnvironmentObject private var preferences: UserPreferencesService
    @EnvironmentObject private var viewModel: SwimViewModel
    @Environment(\.appIsDark) private var appIsDark
    @Binding var selectedTab: Int
    let progressActive: Bool
    let onProgress: (() -> Void)?
    let settingsTitle: String
    let medalsTitle: String
    let progressTitle: String
    let benchmarkTitle: String
    let historyTitle: String

    private var profile: ThemeVisualProfile {
        ThemeVisualProfiles.profile(
            code: preferences.themeCode,
            isDark: appIsDark
        )
    }

    var body: some View {
        barBody()
            .safeAreaPadding(.bottom, TabBarLayout.bottomPadding)
            .frame(maxWidth: .infinity)
            .background {
                barBackground
                    .ignoresSafeArea(edges: .bottom)
            }
            .modifier(ClassicTabBarShadow(enabled: profile.tabBar.usesRaisedShadow))
    }

    private func barBody() -> some View {
        VStack(spacing: 0) {
            if let stripe = profile.tabBar.accentStripe,
               profile.tabBar.accentStripePosition == .top {
                stripe
                    .frame(height: TabBarLayout.topStripeHeight)
                    .frame(maxWidth: .infinity)
            }

            HStack(alignment: .bottom, spacing: 0) {
                tabButton(
                    title: benchmarkTitle,
                    pageKey: "benchmark",
                    icon: TabBarLayout.benchmarkIcon(for: profile.tabBar),
                    tab: 3
                )

                tabButton(
                    title: medalsTitle,
                    pageKey: "medals",
                    icon: TabBarLayout.medalsIcon(for: profile.tabBar),
                    tab: 1
                )

                centerColumn()

                tabButton(
                    title: historyTitle,
                    pageKey: "history",
                    icon: TabBarLayout.historyIcon(for: profile.tabBar),
                    tab: 4
                )

                tabButton(
                    title: settingsTitle,
                    pageKey: "settings",
                    icon: TabBarLayout.settingsIcon(for: profile.tabBar),
                    tab: 2
                )
            }
            .padding(.horizontal, TabBarLayout.horizontalPadding)
            .frame(height: TabBarLayout.barContentHeight, alignment: .bottom)

            if let stripe = profile.tabBar.accentStripe,
               profile.tabBar.accentStripePosition == .bottom {
                stripe
                    .frame(height: TabBarLayout.bottomStripeHeight)
                    .frame(maxWidth: .infinity)
            }
        }
        .overlay {
            if let border = profile.tabBar.borderColor {
                tabBarShape
                    .strokeBorder(border, lineWidth: 1)
            }
        }
    }

    @ViewBuilder
    private func centerColumn() -> some View {
        VStack(spacing: TabBarLayout.itemSpacing) {
            ZStack(alignment: .bottom) {
                if profile.uploadFAB.usesOverlay, let onProgress {
                    CustomCenterFAB(
                        style: profile.uploadFAB,
                        pageKey: "progress",
                        systemImage: TabBarLayout.progressIcon(for: profile.tabBar),
                        usesPlainIcon: profile.tabBar.usesPlainTabIcons,
                        action: onProgress
                    )
                    .offset(y: centerFabOffset())
                }
            }
            .frame(height: centerIconSlotHeight)

            progressLabel
        }
        .frame(maxWidth: .infinity)
        .zIndex(profile.tabBar.accentStripePosition == .top ? 1 : 0)
    }

    private func tabButton(title: String, pageKey: String, icon: String, tab: Int) -> some View {
        CustomTabButton(
            title: title,
            pageKey: pageKey,
            icon: icon,
            isActive: selectedTab == tab,
            selectedColor: profile.tabBar.selectedColor,
            unselectedColor: profile.tabBar.unselectedColor,
            usesThemeFont: profile.tabBar.usesThemeFont,
            usesPlainTabIcons: profile.tabBar.usesPlainTabIcons,
            iconSize: TabBarLayout.iconSize(for: profile.tabBar),
            themeCode: preferences.themeCode,
            fadesUnselected: profile.tabBar.fadesUnselectedLabels
        ) {
            selectedTab = tab
        }
    }

    private var centerIconSlotHeight: CGFloat {
        TabBarLayout.iconSize(for: profile.tabBar) + TabBarLayout.itemSpacing
    }

    private func uploadLabelTopY() -> CGFloat {
        TabBarLayout.barContentHeight - TabBarLayout.labelHeight
    }

    private func centerFabOffset() -> CGFloat {
        if profile.tabBar.usesPlainTabIcons {
            return -TabBarLayout.classicFabLift
        }
        let maxBottom = uploadLabelTopY() - TabBarLayout.itemSpacing
        let maxInset = maxBottom - TabBarLayout.fabDiameter / 2
        let inset = min(TabBarLayout.fabSeatInset, maxInset)
        return -(TabBarLayout.fabDiameter / 2) + inset
    }

    @ViewBuilder
    private var progressLabel: some View {
        let inactiveColor = profile.tabBar.fabLabelInactiveColor ?? profile.tabBar.unselectedColor
        let labelColor = progressActive ? profile.tabBar.selectedColor : inactiveColor
        let labelWeight: Font.Weight = progressActive ? .bold : .medium

        Text(progressTitle)
            .themeFont(.caption2, weight: labelWeight)
            .tracking(profile.tabBar.usesThemeFont ? ThemeTypography.headingTracking(for: preferences.themeCode) : 0)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(labelColor)
    }

    private var tabBarShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: profile.tabBar.topCornerRadius,
            topTrailingRadius: profile.tabBar.topCornerRadius
        )
    }

    @ViewBuilder
    private var barBackground: some View {
        if let gradient = profile.tabBar.backgroundGradient, gradient.count >= 2 {
            LinearGradient(
                colors: gradient,
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if profile.tabBar.background == .clear {
            Rectangle()
                .fill(.ultraThinMaterial)
        } else {
            profile.tabBar.background
        }
    }
}

private struct ClassicTabBarShadow: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content
                .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: -1)
                .shadow(color: Color.black.opacity(0.14), radius: 0, x: 0, y: -2)
        } else {
            content
        }
    }
}

struct CustomTabButton: View {
    let title: String
    let pageKey: String
    let icon: String
    let isActive: Bool
    let selectedColor: Color
    let unselectedColor: Color
    let usesThemeFont: Bool
    var usesPlainTabIcons: Bool = false
    var iconSize: CGFloat = TabBarLayout.iconSize
    let themeCode: String
    let fadesUnselected: Bool
    let action: () -> Void

    @EnvironmentObject private var viewModel: SwimViewModel

    var body: some View {
        VStack(spacing: TabBarLayout.itemSpacing) {
            tabIcon
            Text(title)
                .themeFont(.caption2, weight: isActive ? .bold : .medium)
                .tracking(usesThemeFont ? ThemeTypography.headingTracking(for: themeCode) : 0)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(labelColor)
        .frame(maxWidth: .infinity, alignment: .bottom)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }

    @ViewBuilder
    private var tabIcon: some View {
        Image(systemName: icon)
            .font(.system(size: iconSize, weight: isActive ? .semibold : .medium))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(labelColor)
            .frame(width: iconSize, height: iconSize)
    }

    private var labelColor: Color {
        if isActive {
            return selectedColor
        }
        return fadesUnselected ? unselectedColor.opacity(0.7) : unselectedColor
    }
}

struct CustomCenterFAB: View {
    let style: ThemeUploadFABStyle
    let pageKey: String
    let systemImage: String
    var usesPlainIcon: Bool = false
    let action: () -> Void
    @EnvironmentObject private var viewModel: SwimViewModel

    var body: some View {
        Button(action: action) {
            fabContent
        }
        .buttonStyle(TabBarTapButtonStyle())
        .accessibilityLabel("Progress")
    }

    @ViewBuilder
    private var fabContent: some View {
        ZStack(alignment: .bottom) {
            Image(systemName: systemImage)
                .font(.system(size: usesPlainIcon ? TabBarLayout.fabIconSize : TabBarLayout.fabIconSize, weight: usesPlainIcon ? .medium : .bold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(style.iconColor)
            .frame(width: TabBarLayout.fabDiameter, height: TabBarLayout.fabDiameter)
            .background {
                Circle().fill(fabFill)
            }
            .overlay {
                Circle()
                    .strokeBorder(style.borderColor, lineWidth: style.borderWidth)
            }
            .overlay {
                if style.usesBorderBottomAccent, let bottomAccent = style.bottomAccent {
                    Circle()
                        .stroke(bottomAccent, lineWidth: style.borderWidth)
                        .mask(alignment: .bottom) {
                            Rectangle()
                                .frame(height: style.borderWidth * 4)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        }
                }
            }
            .modifier(ClassicFABShadow(style: style))

            if !style.usesBorderBottomAccent, let bottomAccent = style.bottomAccent {
                bottomAccent
                    .frame(width: 34, height: style.borderWidth)
                    .clipShape(Capsule())
                    .offset(y: -2)
            }
        }
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
            AnyShapeStyle(Color.yellow)
        }
    }
}

private struct TabBarTapButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

private struct ClassicFABShadow: ViewModifier {
    let style: ThemeUploadFABStyle

    func body(content: Content) -> some View {
        if style.usesRaisedShadow {
            content
                .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 2)
                .shadow(color: Color.black.opacity(0.14), radius: 0, x: 0, y: 2)
        } else {
            content
                .shadow(color: style.shadowColor, radius: 10, x: 0, y: 4)
        }
    }
}
