import SwiftUI

enum MascotCoachLayout {
    case automatic
    case stacked
    case sideBySide
}

struct MascotCoachView: View {
    @EnvironmentObject private var preferences: UserPreferencesService
    @Environment(\.appIsDark) private var appIsDark
    @Environment(\.appAnimationsPaused) private var animationsPaused

    let mascotId: String
    let message: String
    var mood: String = "happy"
    var level: String? = nil
    var bubbleTone: MascotBubbleTone = .default
    var coachName: String? = nil
    var showLevelBadge: Bool = true
    var showStage: Bool = true
    var size: CGFloat = 220
    var animated: Bool = true
    var layout: MascotCoachLayout = .automatic

    private var resolvedLevel: String {
        level ?? MascotConstants.coachedLevel(mascotId)
    }

    private var resolvedCoachName: String {
        coachName ?? MascotConstants.displayName(mascotId, t: preferences.translations)
    }

    private var motionEnabled: Bool {
        animated && !animationsPaused
    }

    var body: some View {
        Group {
            if showStage {
                MascotStageView(mascotId: mascotId) {
                    coachContent
                }
            } else {
                coachContent
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var coachContent: some View {
        switch layout {
        case .stacked:
            stackedLayout
        case .sideBySide:
            sideBySideLayout
        case .automatic:
            AdaptiveMascotCoachLayout(breakpoint: sideBySideBreakpoint) { usesSideBySide in
                if usesSideBySide {
                    sideBySideLayout
                } else {
                    stackedLayout
                }
            }
        }
    }

    private var sideBySideBreakpoint: CGFloat {
        size * MascotConstants.aspectRatio(mascotId) + 240
    }

    private var stackedLayout: some View {
        VStack(spacing: 16) {
            headerRow(alignCenter: true)
            MascotSpeechBubbleView(
                message: message,
                tone: bubbleTone,
                mascotId: mascotId,
                tail: .bottom
            )
            .frame(maxWidth: .infinity)
            mascotColumn
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    private var sideBySideLayout: some View {
        HStack(alignment: .bottom, spacing: 20) {
            mascotColumn
            VStack(alignment: .leading, spacing: 10) {
                headerRow(alignCenter: false)
                MascotSpeechBubbleView(
                    message: message,
                    tone: bubbleTone,
                    mascotId: mascotId,
                    tail: .left
                )
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func headerRow(alignCenter: Bool) -> some View {
        HStack(spacing: 10) {
            Text(resolvedCoachName.uppercased())
                .themeFont(.caption, weight: .bold)
                .tracking(1.2)
                .foregroundStyle(
                    MascotPresentation.coachNameColor(
                        mascotId: mascotId,
                        colorScheme: appIsDark ? .dark : .light
                    )
                )

            if showLevelBadge {
                MascotLevelBadgeView(level: resolvedLevel)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignCenter ? .center : .leading)
    }

    private var mascotColumn: some View {
        VStack(spacing: 0) {
            MascotCharacterView(
                mascotId: mascotId,
                mood: mood,
                animated: motionEnabled,
                size: size
            )
            MascotShadowPulseView(size: size, animated: motionEnabled)
        }
        .modifier(MascotEnterModifier(enabled: motionEnabled))
    }
}

/// Matches web `.mascot-shadow` pulse (`styles/globals.css`).
private struct MascotShadowPulseView: View {
    let size: CGFloat
    let animated: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appIsDark) private var appIsDark

    var body: some View {
        let pulseEnabled = animated && !reduceMotion

        Group {
            if pulseEnabled {
                TimelineView(BatteryEfficientAnimation.timelineSchedule) { timeline in
                    let elapsed = timeline.date.timeIntervalSinceReferenceDate
                    let progress = (elapsed.truncatingRemainder(dividingBy: 4.2)) / 4.2
                    let scaleX = MascotIdleMotion.interpolate(
                        progress,
                        keyframes: [(0, 1), (0.3, 0.88), (0.6, 0.97), (1, 1)]
                    )
                    let opacity = MascotIdleMotion.interpolate(
                        progress,
                        keyframes: [(0, 0.7), (0.3, 0.45), (0.6, 0.62), (1, 0.7)]
                    )

                    shadowBody
                        .scaleEffect(x: scaleX, y: 1, anchor: .center)
                        .opacity(Double(opacity))
                }
            } else {
                shadowBody.opacity(0.7)
            }
        }
        .offset(y: -4)
    }

    private var shadowBody: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        (appIsDark ? Color.black : Color(red: 0.11, green: 0.18, blue: 0.35))
                            .opacity(appIsDark ? 0.5 : 0.22),
                        .clear,
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.35
                )
            )
            .frame(width: size * 0.7, height: size * 0.12)
    }
}

/// Matches web `.mascot-enter` one-shot entrance.
private struct MascotEnterModifier: ViewModifier {
    let enabled: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var entered = false

    func body(content: Content) -> some View {
        content
            .opacity(entered ? 1 : 0)
            .offset(y: entered ? 0 : 12)
            .scaleEffect(entered ? 1 : 0.95, anchor: .bottom)
            .onAppear {
                guard enabled, !reduceMotion else {
                    entered = true
                    return
                }
                withAnimation(.timingCurve(0.34, 1.4, 0.64, 1, duration: 0.5)) {
                    entered = true
                }
            }
    }
}

private struct AdaptiveMascotCoachLayout<Content: View>: View {
    let breakpoint: CGFloat
    @ViewBuilder let content: (_ usesSideBySide: Bool) -> Content

    @State private var width: CGFloat = 0

    var body: some View {
        content(width >= breakpoint)
            .frame(maxWidth: .infinity)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { width = proxy.size.width }
                        .onChange(of: proxy.size.width) { _, newWidth in
                            width = newWidth
                        }
                }
            }
    }
}
