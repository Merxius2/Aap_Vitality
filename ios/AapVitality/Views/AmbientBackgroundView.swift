import SwiftUI

enum AmbientCatalog {
    static let allIds = [
        "ambient:neon-lagoon",
        "ambient:sunset-lap",
        "ambient:bubble-trail",
        "ambient:aurora-lap",
        "ambient:deep-current",
        "ambient:green-leaves",
    ]

    static func isValid(_ id: String?) -> Bool {
        guard let id else { return false }
        return allIds.contains(id)
    }

    static func nameKey(for id: String) -> String {
        switch id {
        case "ambient:neon-lagoon": return "settings.ambients.neonLagoon"
        case "ambient:sunset-lap": return "settings.ambients.sunsetLap"
        case "ambient:bubble-trail": return "settings.ambients.bubbleTrail"
        case "ambient:aurora-lap": return "settings.ambients.auroraLap"
        case "ambient:deep-current": return "settings.ambients.deepCurrent"
        case "ambient:green-leaves": return "settings.ambients.greenLeaves"
        default: return id
        }
    }
}

enum AmbientBackgroundState {
    static func isVisible(activeAmbient: String?) -> Bool {
        AmbientCatalog.isValid(activeAmbient)
    }
}

struct AmbientOverlayView: View {
    let activeAmbient: String?

    var body: some View {
        Group {
            if let preset = resolvedPreset {
                AmbientPresetRenderer(preset: preset)
                    .opacity(0.72)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var resolvedPreset: AmbientPreset? {
        guard let activeAmbient, AmbientCatalog.isValid(activeAmbient) else { return nil }
        return AmbientPresets.preset(for: activeAmbient)
    }
}

/// Renders an ambient preset — used as a translucent overlay and in settings previews.
struct AmbientPresetRenderer: View {
    let preset: AmbientPreset
    var isPreview: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appAnimationsPaused) private var animationsPaused

    var body: some View {
        GeometryReader { proxy in
            let motionEnabled = !reduceMotion && !animationsPaused && !isPreview

            Group {
                if motionEnabled, preset.gradient != nil || preset.driftBlobs {
                    TimelineView(BatteryEfficientAnimation.timelineSchedule) { timeline in
                        presetContent(
                            in: proxy.size,
                            elapsed: timeline.date.timeIntervalSinceReferenceDate
                        )
                    }
                } else {
                    presetContent(in: proxy.size, elapsed: 0)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    @ViewBuilder
    private func presetContent(in size: CGSize, elapsed: TimeInterval) -> some View {
        ZStack {
            if let gradient = renderedGradient {
                AnimatedAmbientGradient(
                    spec: gradient,
                    containerSize: size,
                    elapsed: elapsed
                )
            }

            ForEach(Array(preset.blobs.enumerated()), id: \.offset) { index, blob in
                blobView(blob, in: size, index: index, elapsed: elapsed)
            }

            if preset.bubbles && isPreview {
                bubbleTrail(in: size, elapsed: elapsed)
            }

            if preset.leaves && isPreview {
                leafDrift(in: size, elapsed: elapsed)
            }
        }
    }

    private var renderedGradient: AmbientGradientSpec? {
        guard let gradient = preset.gradient else { return nil }
        guard isPreview else { return gradient }
        return AmbientGradientSpec(colors: gradient.colors, duration: 5, vertical: gradient.vertical)
    }

    private var blobBlur: CGFloat { isPreview ? 22 : 40 }

    @ViewBuilder
    private func blobView(
        _ blob: AmbientBlob,
        in size: CGSize,
        index: Int,
        elapsed: TimeInterval
    ) -> some View {
        let width = size.width * blob.widthRatio
        let height = size.height * blob.heightRatio
        let x = blob.xRatio.map { $0 * size.width } ?? (blob.rightRatio.map { size.width - $0 * size.width - width } ?? 0)
        let y = blob.yRatio.map { $0 * size.height } ?? (blob.bottomRatio.map { size.height - $0 * size.height - height } ?? 0)
        let driftDuration = isPreview ? 10.0 : 28.0
        let driftPhase = preset.driftBlobs
            ? (elapsed.truncatingRemainder(dividingBy: driftDuration)) / driftDuration
            : 0
        let driftOffset = preset.driftBlobs
            ? CGSize(
                width: sin(driftPhase * .pi * 2 + CGFloat(index)) * (isPreview ? 6 : 12),
                height: cos(driftPhase * .pi * 2 + CGFloat(index)) * (isPreview ? 5 : 10)
            )
            : .zero

        Circle()
            .fill(
                RadialGradient(
                    colors: [blob.color.opacity(blob.opacity), blob.color.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: max(width, height) * 0.5
                )
            )
            .frame(width: width, height: height)
            .offset(x: x + driftOffset.width, y: y + driftOffset.height)
            .blur(radius: blobBlur)
    }

    @ViewBuilder
    private func bubbleTrail(in size: CGSize, elapsed: TimeInterval) -> some View {
        let bubbles = Array(AmbientPresets.bubblePositions.prefix(6))
        let sizeScale: CGFloat = 0.42
        let durationScale = 0.45

        ForEach(bubbles.indices, id: \.self) { index in
            let bubble = bubbles[index]
            RisingBubble(
                size: bubble.size * sizeScale,
                leftRatio: bubble.leftRatio,
                containerSize: size,
                delay: bubble.delay * durationScale,
                duration: bubble.duration * durationScale,
                elapsed: elapsed
            )
        }
    }

    @ViewBuilder
    private func leafDrift(in size: CGSize, elapsed: TimeInterval) -> some View {
        let leaves = Array(AmbientPresets.leafPositions.prefix(5))
        let sizeScale: CGFloat = 0.55
        let durationScale = 0.55

        ForEach(leaves.indices, id: \.self) { index in
            let leaf = leaves[index]
            DriftingLeaf(
                size: leaf.size * sizeScale,
                startYRatio: leaf.startYRatio,
                containerSize: size,
                delay: leaf.delay * durationScale,
                duration: leaf.duration * durationScale,
                elapsed: elapsed,
                tint: leaf.tint
            )
        }
    }
}

struct AmbientLeafOverlayView: View {
    let activeAmbient: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appAnimationsPaused) private var animationsPaused

    private var showsLeaves: Bool {
        guard let activeAmbient,
              AmbientCatalog.isValid(activeAmbient),
              let preset = AmbientPresets.preset(for: activeAmbient) else {
            return false
        }
        return preset.leaves
    }

    var body: some View {
        if showsLeaves {
            GeometryReader { proxy in
                let motionEnabled = !reduceMotion && !animationsPaused

                Group {
                    if motionEnabled {
                        TimelineView(BatteryEfficientAnimation.timelineSchedule) { timeline in
                            leafLayer(
                                in: proxy.size,
                                elapsed: timeline.date.timeIntervalSinceReferenceDate
                            )
                        }
                    } else {
                        leafLayer(in: proxy.size, elapsed: 0)
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func leafLayer(in size: CGSize, elapsed: TimeInterval) -> some View {
        ZStack {
            ForEach(AmbientPresets.leafPositions.indices, id: \.self) { index in
                let leaf = AmbientPresets.leafPositions[index]
                DriftingLeaf(
                    size: leaf.size,
                    startYRatio: leaf.startYRatio,
                    containerSize: size,
                    delay: leaf.delay,
                    duration: leaf.duration,
                    elapsed: elapsed,
                    tint: leaf.tint
                )
                .allowsHitTesting(false)
            }
        }
    }
}

struct AmbientBubbleOverlayView: View {
    let activeAmbient: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appAnimationsPaused) private var animationsPaused

    private var showsBubbles: Bool {
        guard let activeAmbient,
              AmbientCatalog.isValid(activeAmbient),
              let preset = AmbientPresets.preset(for: activeAmbient) else {
            return false
        }
        return preset.bubbles
    }

    var body: some View {
        if showsBubbles {
            GeometryReader { proxy in
                let motionEnabled = !reduceMotion && !animationsPaused

                Group {
                    if motionEnabled {
                        TimelineView(BatteryEfficientAnimation.timelineSchedule) { timeline in
                            bubbleLayer(
                                in: proxy.size,
                                elapsed: timeline.date.timeIntervalSinceReferenceDate
                            )
                        }
                    } else {
                        bubbleLayer(in: proxy.size, elapsed: 0)
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func bubbleLayer(in size: CGSize, elapsed: TimeInterval) -> some View {
        ZStack {
            ForEach(AmbientPresets.bubblePositions.indices, id: \.self) { index in
                let bubble = AmbientPresets.bubblePositions[index]
                RisingBubble(
                    size: bubble.size,
                    leftRatio: bubble.leftRatio,
                    containerSize: size,
                    delay: bubble.delay,
                    duration: bubble.duration,
                    elapsed: elapsed
                )
                .allowsHitTesting(false)
            }
        }
    }
}

private struct AnimatedAmbientGradient: View {
    let spec: AmbientGradientSpec
    let containerSize: CGSize
    let elapsed: TimeInterval

    var body: some View {
        let width = max(containerSize.width, 1)
        let height = max(containerSize.height, 1)
        let cycle = max(spec.duration, 0.1)
        let progress = (elapsed.truncatingRemainder(dividingBy: cycle)) / cycle
        let wave = sin(progress * .pi * 2)
        let scale: CGFloat = spec.vertical ? 1.05 : 1.06
        let offsetX = spec.vertical ? 0 : CGFloat(wave) * width * 0.10
        let offsetY = spec.vertical
            ? CGFloat(wave) * height * 0.08
            : CGFloat(wave) * height * 0.06

        gradientLayer
            .frame(
                width: width * (spec.vertical ? 1.0 : 1.6),
                height: height * (spec.vertical ? 2.2 : 1.6)
            )
            .scaleEffect(spec.vertical ? 1.0 : (1 + (scale - 1) * abs(CGFloat(wave))))
            .offset(x: offsetX, y: offsetY)
            .position(x: width * 0.5, y: height * 0.5)
            .frame(width: width, height: height)
            .clipped()
            .ignoresSafeArea()
    }

    private var gradientLayer: some View {
        LinearGradient(
            colors: spec.colors,
            startPoint: spec.vertical ? .top : .topLeading,
            endPoint: spec.vertical ? .bottom : .bottomTrailing
        )
    }
}

private struct RisingBubble: View {
    let size: CGFloat
    let leftRatio: CGFloat
    let containerSize: CGSize
    let delay: Double
    let duration: Double
    let elapsed: TimeInterval

    var body: some View {
        let cycle = max(duration, 0.1)
        let shifted = elapsed - delay
        let progress = shifted < 0
            ? 0.0
            : (shifted.truncatingRemainder(dividingBy: cycle)) / cycle
        let y = containerSize.height * (0.85 - progress * 0.95)
        let fade = progress < 0.08
            ? progress / 0.08
            : max(0, 1 - (progress - 0.08) / 0.92)

        Circle()
            .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
            .frame(width: size, height: size)
            .position(x: containerSize.width * leftRatio, y: y)
            .opacity(0.85 * fade)
    }
}

private struct DriftingLeaf: View {
    let size: CGFloat
    let startYRatio: CGFloat
    let containerSize: CGSize
    let delay: Double
    let duration: Double
    let elapsed: TimeInterval
    let tint: Color

    var body: some View {
        let cycle = max(duration, 0.1)
        let shifted = elapsed - delay
        let progress = shifted < 0
            ? 0.0
            : (shifted.truncatingRemainder(dividingBy: cycle)) / cycle
        let x = containerSize.width * (-0.10 + progress * 1.20)
        let sway = sin(progress * .pi * 5) * containerSize.height * 0.025
        let y = containerSize.height * startYRatio + sway
        let rotation = sin(progress * .pi * 3) * 22 + 28
        let fade = progress < 0.06
            ? progress / 0.06
            : max(0, 1 - (progress - 0.90) / 0.10)

        LeafShape()
            .fill(
                LinearGradient(
                    colors: [tint.opacity(0.95), tint.opacity(0.55)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size * 1.35)
            .rotationEffect(.degrees(rotation))
            .position(x: x, y: y)
            .opacity(0.88 * fade)
    }
}

private struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.maxX * 0.95, y: rect.minY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.midY),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        return path
    }
}

struct AmbientBlob {
    let color: Color
    let opacity: Double
    let widthRatio: CGFloat
    let heightRatio: CGFloat
    var xRatio: CGFloat?
    var yRatio: CGFloat?
    var rightRatio: CGFloat?
    var bottomRatio: CGFloat?
}

struct AmbientGradientSpec {
    let colors: [Color]
    let duration: Double
    let vertical: Bool
}

struct AmbientPreset {
    let gradient: AmbientGradientSpec?
    let blobs: [AmbientBlob]
    let driftBlobs: Bool
    let bubbles: Bool
    let leaves: Bool
}

enum AmbientPresets {
    static let bubblePositions: [(leftRatio: CGFloat, size: CGFloat, delay: Double, duration: Double)] = [
        (0.06, 28, 0, 9), (0.14, 18, 2.4, 11), (0.24, 34, 0.8, 10.5), (0.33, 22, 3.6, 12),
        (0.42, 16, 1.2, 8.5), (0.51, 30, 4.2, 11.5), (0.60, 20, 0.3, 9.8), (0.69, 26, 2.8, 10.2),
        (0.78, 14, 5, 8), (0.87, 32, 1.6, 12.5), (0.93, 18, 3.2, 9.2), (0.48, 24, 6, 13),
    ]

    static let leafPositions: [(startYRatio: CGFloat, size: CGFloat, delay: Double, duration: Double, tint: Color)] = [
        (0.18, 22, 0, 14, Color(hex: "#4ADE80")),
        (0.32, 18, 2.5, 16, Color(hex: "#22C55E")),
        (0.48, 26, 1.2, 15, Color(hex: "#86EFAC")),
        (0.62, 20, 4.0, 17, Color(hex: "#16A34A")),
        (0.26, 16, 5.5, 13, Color(hex: "#BBF7D0")),
        (0.74, 24, 3.2, 18, Color(hex: "#15803D")),
        (0.40, 19, 6.8, 15, Color(hex: "#65A30D")),
        (0.56, 21, 8.0, 16, Color(hex: "#34D399")),
    ]

    static func preset(for id: String) -> AmbientPreset? {
        switch id {
        case "ambient:neon-lagoon":
            return AmbientPreset(
                gradient: AmbientGradientSpec(
                    colors: [
                        Color(hex: "#020617"), Color(hex: "#0C1445"), Color(hex: "#1A0533"),
                        Color(hex: "#7C3AED"), Color(hex: "#00E5FF"), Color(hex: "#FF00AA"),
                        Color(hex: "#020617"),
                    ],
                    duration: 18,
                    vertical: false
                ),
                blobs: [
                    blob("#00E5FF", 0.55, 0.58, -0.12, -0.12),
                    blob("#FF00AA", 0.45, 0.48, nil, 0.05, right: 0.08),
                    blob("#7C3AED", 0.40, 0.62, 0.10, nil, bottom: 0.20),
                    blob("#22D3EE", 0.35, 0.30, nil, nil, right: 0.15, bottom: 0.10),
                ],
                driftBlobs: true,
                bubbles: false,
                leaves: false
            )
        case "ambient:sunset-lap":
            return AmbientPreset(
                gradient: AmbientGradientSpec(
                    colors: [
                        Color(hex: "#431407"), Color(hex: "#9A3412"), Color(hex: "#FB923C"),
                        Color(hex: "#F472B6"), Color(hex: "#FBBF24"), Color(hex: "#7C2D12"),
                        Color(hex: "#1C1917"),
                    ],
                    duration: 22,
                    vertical: false
                ),
                blobs: [
                    blob("#FB923C", 0.65, 0.65, -0.10, -0.15),
                    blob("#F472B6", 0.45, 0.50, nil, 0.10, right: 0.12),
                    blob("#FBBF24", 0.50, 0.55, 0.05, nil, bottom: 0.18),
                    blob("#EF4444", 0.35, 0.38, nil, nil, right: 0.08, bottom: 0.08),
                ],
                driftBlobs: true,
                bubbles: false,
                leaves: false
            )
        case "ambient:bubble-trail":
            return AmbientPreset(
                gradient: AmbientGradientSpec(
                    colors: [
                        Color(hex: "#0EA5E9"), Color(hex: "#0284C7"), Color(hex: "#0369A1"),
                        Color(hex: "#0C4A6E"), Color(hex: "#082F49"),
                    ],
                    duration: 16,
                    vertical: true
                ),
                blobs: [
                    blob("#BAE6FD", 0.45, 0.45, -0.05, -0.08),
                    blob("#A5F3FC", 0.40, 0.40, nil, nil, right: 0.05, bottom: 0.10),
                ],
                driftBlobs: false,
                bubbles: true,
                leaves: false
            )
        case "ambient:aurora-lap":
            return AmbientPreset(
                gradient: AmbientGradientSpec(
                    colors: [
                        Color(hex: "#042F2E"), Color(hex: "#134E4A"), Color(hex: "#065F46"),
                        Color(hex: "#312E81"), Color(hex: "#4338CA"), Color(hex: "#0E7490"),
                        Color(hex: "#042F2E"),
                    ],
                    duration: 20,
                    vertical: false
                ),
                blobs: [
                    blob("#34D399", 0.40, 0.55, -0.10, -0.12),
                    blob("#818CF8", 0.45, 0.48, nil, 0.08, right: 0.08),
                    blob("#22D3EE", 0.35, 0.60, 0.08, nil, bottom: 0.22),
                    blob("#A78BFA", 0.30, 0.32, nil, nil, right: 0.12, bottom: 0.12),
                ],
                driftBlobs: true,
                bubbles: false,
                leaves: false
            )
        case "ambient:deep-current":
            return AmbientPreset(
                gradient: AmbientGradientSpec(
                    colors: [
                        Color(hex: "#020617"), Color(hex: "#0C4A6E"), Color(hex: "#0369A1"),
                        Color(hex: "#164E63"), Color(hex: "#0EA5E9"), Color(hex: "#082F49"),
                        Color(hex: "#020617"),
                    ],
                    duration: 24,
                    vertical: false
                ),
                blobs: [
                    blob("#0EA5E9", 0.45, 0.58, -0.12, -0.10),
                    blob("#0369A1", 0.50, 0.52, nil, 0.12, right: 0.10),
                    blob("#164E63", 0.55, 0.64, 0.06, nil, bottom: 0.20),
                ],
                driftBlobs: true,
                bubbles: false,
                leaves: false
            )
        case "ambient:green-leaves":
            return AmbientPreset(
                gradient: AmbientGradientSpec(
                    colors: [
                        Color(hex: "#ECFDF5"), Color(hex: "#BBF7D0"), Color(hex: "#4ADE80"),
                        Color(hex: "#16A34A"), Color(hex: "#14532D"),
                    ],
                    duration: 20,
                    vertical: true
                ),
                blobs: [
                    blob("#86EFAC", 0.40, 0.50, -0.08, -0.10),
                    blob("#22C55E", 0.35, 0.42, nil, nil, right: 0.10, bottom: 0.12),
                    blob("#A3E635", 0.30, 0.38, 0.08, nil, bottom: 0.18),
                ],
                driftBlobs: true,
                bubbles: false,
                leaves: true
            )
        default:
            return nil
        }
    }

    private static func blob(
        _ hex: String,
        _ opacity: Double,
        _ width: CGFloat,
        _ x: CGFloat?,
        _ y: CGFloat?,
        right: CGFloat? = nil,
        bottom: CGFloat? = nil
    ) -> AmbientBlob {
        AmbientBlob(
            color: Color(hex: hex),
            opacity: opacity,
            widthRatio: width,
            heightRatio: width,
            xRatio: x,
            yRatio: y,
            rightRatio: right,
            bottomRatio: bottom
        )
    }
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

enum WallpaperCatalog {
    static let allIds = [
        "wallpaper:lane-pool",
        "wallpaper:dawn-water",
        "wallpaper:deep-lane",
        "wallpaper:tile-deck",
        "wallpaper:open-water",
        "wallpaper:chlorine-glow",
        "wallpaper:vitality-pulse",
        "wallpaper:morning-steps",
        "wallpaper:achievement-gold",
        "wallpaper:twilight-run",
    ]

    static func isValid(_ id: String?) -> Bool {
        guard let id else { return false }
        return allIds.contains(id)
    }

    static func nameKey(for id: String) -> String {
        switch id {
        case "wallpaper:lane-pool": return "settings.wallpapers.lanePool"
        case "wallpaper:dawn-water": return "settings.wallpapers.dawnWater"
        case "wallpaper:deep-lane": return "settings.wallpapers.deepLane"
        case "wallpaper:tile-deck": return "settings.wallpapers.tileDeck"
        case "wallpaper:open-water": return "settings.wallpapers.openWater"
        case "wallpaper:chlorine-glow": return "settings.wallpapers.chlorineGlow"
        case "wallpaper:vitality-pulse": return "settings.wallpapers.vitalityPulse"
        case "wallpaper:morning-steps": return "settings.wallpapers.morningSteps"
        case "wallpaper:achievement-gold": return "settings.wallpapers.achievementGold"
        case "wallpaper:twilight-run": return "settings.wallpapers.twilightRun"
        default: return id
        }
    }
}

/// True when a custom wallpaper and/or vibe should show under UI chrome.
enum BackdropState {
    static func isCustomVisible(activeWallpaper: String?, activeAmbient: String?) -> Bool {
        WallpaperCatalog.isValid(activeWallpaper) || AmbientCatalog.isValid(activeAmbient)
    }
}

struct AppBackdropView: View {
    let themeCode: String
    let isDark: Bool
    let activeWallpaper: String?
    let activeAmbient: String?

    private var themePageBackground: ThemePageBackground {
        ThemeVisualProfiles.profile(code: themeCode, isDark: isDark).pageBackground
    }

    var body: some View {
        ZStack {
            if let wallpaperId = activeWallpaper, WallpaperCatalog.isValid(wallpaperId) {
                WallpaperCanvasView(id: wallpaperId)
            } else {
                ThemedPageBackgroundView(background: themePageBackground)
            }

            if AmbientCatalog.isValid(activeAmbient) {
                AmbientOverlayView(activeAmbient: activeAmbient)
                    .id(activeAmbient ?? "none")
                AmbientBubbleOverlayView(activeAmbient: activeAmbient)
                AmbientLeafOverlayView(activeAmbient: activeAmbient)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct WallpaperCanvasView: View {
    let id: String

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            switch id {
            case "wallpaper:lane-pool":
                lanePool(size: size)
            case "wallpaper:dawn-water":
                dawnWater(size: size)
            case "wallpaper:deep-lane":
                deepLane(size: size)
            case "wallpaper:tile-deck":
                tileDeck(size: size)
            case "wallpaper:open-water":
                openWater(size: size)
            case "wallpaper:chlorine-glow":
                chlorineGlow(size: size)
            case "wallpaper:vitality-pulse":
                vitalityPulse(size: size)
            case "wallpaper:morning-steps":
                morningSteps(size: size)
            case "wallpaper:achievement-gold":
                achievementGold(size: size)
            case "wallpaper:twilight-run":
                twilightRun(size: size)
            default:
                Color(.systemGroupedBackground)
            }
        }
        .ignoresSafeArea()
    }

    private func lanePool(size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.72, green: 0.88, blue: 0.98),
                    Color(red: 0.20, green: 0.55, blue: 0.82),
                    Color(red: 0.05, green: 0.32, blue: 0.58),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            ForEach(0..<6, id: \.self) { index in
                let x = size.width * (0.12 + CGFloat(index) * 0.15)
                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 3)
                    .position(x: x, y: size.height * 0.58)
                    .frame(height: size.height * 0.7)
            }
            Ellipse()
                .fill(Color.white.opacity(0.12))
                .frame(width: size.width * 1.1, height: size.height * 0.18)
                .position(x: size.width * 0.5, y: size.height * 0.22)
        }
    }

    private func dawnWater(size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.78, blue: 0.55),
                    Color(red: 0.98, green: 0.62, blue: 0.48),
                    Color(red: 0.35, green: 0.55, blue: 0.72),
                    Color(red: 0.12, green: 0.28, blue: 0.45),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color(red: 1.0, green: 0.92, blue: 0.75).opacity(0.55))
                .frame(width: size.width * 0.42, height: size.width * 0.42)
                .blur(radius: 30)
                .position(x: size.width * 0.72, y: size.height * 0.18)
            waveBands(size: size, color: Color.white.opacity(0.14), count: 4, startY: 0.55)
        }
    }

    private func deepLane(size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.10, blue: 0.22),
                    Color(red: 0.04, green: 0.18, blue: 0.36),
                    Color(red: 0.02, green: 0.08, blue: 0.16),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.35, green: 0.75, blue: 0.95).opacity(0.0),
                                Color(red: 0.35, green: 0.75, blue: 0.95).opacity(0.22),
                                Color(red: 0.35, green: 0.75, blue: 0.95).opacity(0.0),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size.width * 0.18, height: size.height * 0.9)
                    .rotationEffect(.degrees(-8 + Double(index) * 8))
                    .position(x: size.width * (0.28 + CGFloat(index) * 0.22), y: size.height * 0.45)
                    .blur(radius: 18)
            }
        }
    }

    private func tileDeck(size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.86, green: 0.93, blue: 0.96),
                    Color(red: 0.62, green: 0.82, blue: 0.88),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            Canvas { context, canvasSize in
                let step: CGFloat = 36
                var path = Path()
                var x: CGFloat = 0
                while x <= canvasSize.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: canvasSize.height))
                    x += step
                }
                var y: CGFloat = 0
                while y <= canvasSize.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: canvasSize.width, y: y))
                    y += step
                }
                context.stroke(path, with: .color(Color.white.opacity(0.35)), lineWidth: 1)
            }
            .opacity(0.7)
            Ellipse()
                .fill(Color(red: 0.25, green: 0.62, blue: 0.78).opacity(0.18))
                .frame(width: size.width * 0.9, height: size.height * 0.35)
                .position(x: size.width * 0.5, y: size.height * 0.72)
                .blur(radius: 24)
        }
    }

    private func openWater(size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.78, green: 0.90, blue: 0.92),
                    Color(red: 0.35, green: 0.62, blue: 0.68),
                    Color(red: 0.12, green: 0.38, blue: 0.42),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            waveBands(size: size, color: Color.white.opacity(0.16), count: 5, startY: 0.42)
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: size.width * 0.5, height: size.width * 0.5)
                .blur(radius: 40)
                .position(x: size.width * 0.2, y: size.height * 0.15)
        }
    }

    private func chlorineGlow(size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.55, green: 0.92, blue: 0.95),
                    Color(red: 0.15, green: 0.72, blue: 0.82),
                    Color(red: 0.05, green: 0.42, blue: 0.58),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color.white.opacity(0.35))
                .frame(width: size.width * 0.55, height: size.width * 0.55)
                .blur(radius: 36)
                .position(x: size.width * 0.75, y: size.height * 0.2)
            Circle()
                .fill(Color(red: 0.2, green: 0.9, blue: 0.85).opacity(0.25))
                .frame(width: size.width * 0.7, height: size.width * 0.7)
                .blur(radius: 50)
                .position(x: size.width * 0.2, y: size.height * 0.75)
        }
    }

    private func vitalityPulse(size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.10, blue: 0.24),
                    Color(red: 0.16, green: 0.20, blue: 0.42),
                    Color(red: 0.10, green: 0.14, blue: 0.28),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .stroke(Color("BrandBlue").opacity(0.22 - Double(index) * 0.04), lineWidth: 2)
                    .frame(
                        width: size.width * (0.35 + CGFloat(index) * 0.18),
                        height: size.width * (0.35 + CGFloat(index) * 0.18)
                    )
                    .position(x: size.width * 0.5, y: size.height * 0.42)
            }
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.95, green: 0.35, blue: 0.45).opacity(0.55),
                            Color(red: 0.95, green: 0.35, blue: 0.45).opacity(0),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size.width * 0.12
                    )
                )
                .frame(width: size.width * 0.24, height: size.width * 0.24)
                .position(x: size.width * 0.5, y: size.height * 0.42)
            Circle()
                .fill(Color("BrandBlue").opacity(0.18))
                .frame(width: size.width * 0.8, height: size.width * 0.8)
                .blur(radius: 40)
                .position(x: size.width * 0.82, y: size.height * 0.78)
        }
    }

    private func morningSteps(size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.88, green: 0.96, blue: 0.90),
                    Color(red: 0.52, green: 0.82, blue: 0.62),
                    Color(red: 0.18, green: 0.52, blue: 0.38),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(index.isMultiple(of: 2) ? 0.28 : 0.16))
                    .frame(width: 10 + CGFloat(index % 3) * 4, height: 10 + CGFloat(index % 3) * 4)
                    .position(
                        x: size.width * (0.18 + CGFloat(index) * 0.16),
                        y: size.height * (0.62 - CGFloat(index) * 0.04)
                    )
            }
            Capsule()
                .fill(Color.white.opacity(0.14))
                .frame(width: size.width * 0.72, height: 3)
                .rotationEffect(.degrees(-8))
                .position(x: size.width * 0.48, y: size.height * 0.58)
            Circle()
                .fill(Color.white.opacity(0.22))
                .frame(width: size.width * 0.45, height: size.width * 0.45)
                .blur(radius: 30)
                .position(x: size.width * 0.78, y: size.height * 0.22)
        }
    }

    private func achievementGold(size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.92, blue: 0.72),
                    Color(red: 0.98, green: 0.72, blue: 0.38),
                    Color(red: 0.82, green: 0.42, blue: 0.18),
                    Color(red: 0.42, green: 0.18, blue: 0.10),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            ForEach(0..<6, id: \.self) { index in
                let angle = Double(index) * 30 - 15
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: size.width * 0.55, height: 4)
                    .rotationEffect(.degrees(angle))
                    .position(x: size.width * 0.5, y: size.height * 0.28)
            }
            Circle()
                .fill(Color.white.opacity(0.35))
                .frame(width: size.width * 0.38, height: size.width * 0.38)
                .blur(radius: 26)
                .position(x: size.width * 0.68, y: size.height * 0.24)
            Ellipse()
                .fill(Color(red: 1.0, green: 0.78, blue: 0.32).opacity(0.22))
                .frame(width: size.width * 1.0, height: size.height * 0.35)
                .position(x: size.width * 0.5, y: size.height * 0.82)
                .blur(radius: 20)
        }
    }

    private func twilightRun(size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.18, green: 0.12, blue: 0.32),
                    Color(red: 0.52, green: 0.22, blue: 0.42),
                    Color(red: 0.92, green: 0.42, blue: 0.28),
                    Color(red: 0.22, green: 0.10, blue: 0.24),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            Ellipse()
                .fill(Color(red: 1.0, green: 0.55, blue: 0.35).opacity(0.35))
                .frame(width: size.width * 0.55, height: size.width * 0.22)
                .blur(radius: 18)
                .position(x: size.width * 0.5, y: size.height * 0.72)
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: size.width * 0.22, height: 2)
                    .rotationEffect(.degrees(-6))
                    .position(
                        x: size.width * (0.25 + CGFloat(index) * 0.25),
                        y: size.height * (0.78 + CGFloat(index) * 0.03)
                    )
            }
            Circle()
                .fill(Color(red: 0.98, green: 0.72, blue: 0.45).opacity(0.25))
                .frame(width: size.width * 0.35, height: size.width * 0.35)
                .blur(radius: 24)
                .position(x: size.width * 0.2, y: size.height * 0.18)
        }
    }

    private func waveBands(size: CGSize, color: Color, count: Int, startY: CGFloat) -> some View {
        ForEach(0..<count, id: \.self) { index in
            let y = size.height * (startY + CGFloat(index) * 0.08)
            WaveShape(amplitude: 10 + CGFloat(index) * 2, frequency: 1.4)
                .stroke(color, lineWidth: 2)
                .frame(height: 28)
                .offset(y: y - size.height * 0.5)
        }
    }
}

private struct WaveShape: Shape {
    var amplitude: CGFloat
    var frequency: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        path.move(to: CGPoint(x: 0, y: midY))
        let steps = 40
        for step in 0...steps {
            let x = rect.width * CGFloat(step) / CGFloat(steps)
            let y = midY + sin(CGFloat(step) / CGFloat(steps) * .pi * 2 * frequency) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }
}

/// Compact preview tile used in Settings.
struct WallpaperPreviewTile: View {
    let id: String?
    let title: String
    let isSelected: Bool
    let themeCode: String
    let isDark: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if let id {
                    WallpaperCanvasView(id: id)
                } else {
                    ThemedPageBackgroundView(
                        background: ThemeVisualProfiles.profile(code: themeCode, isDark: isDark).pageBackground
                    )
                }
            }
            .frame(width: 92, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: isSelected ? 2.5 : 1)
            }

            Text(title)
                .themeFont(.caption2, weight: isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 92)
        }
    }
}
