import SwiftUI

struct MascotCharacterView: View {
    let mascotId: String
    var mood: String = "happy"
    var animated: Bool = true
    var size: CGFloat = 56

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var blinking = false
    @State private var isOnScreen = false

    var body: some View {
        let disappointed = mood == "disappointed" && MascotConstants.disappointedOpenImageName(mascotId) != nil
        let openName = disappointed
            ? MascotConstants.disappointedOpenImageName(mascotId)!
            : MascotConstants.openImageName(mascotId)
        let closedName = disappointed
            ? (MascotConstants.disappointedClosedImageName(mascotId) ?? MascotConstants.closedImageName(mascotId))
            : MascotConstants.closedImageName(mascotId)
        let width = size * MascotConstants.aspectRatio(mascotId)
        let idleMotionEnabled = animated && !reduceMotion

        ZStack {
            Image(openName)
                .resizable()
                .scaledToFit()
                .opacity(blinking ? 0 : 1)
            Image(closedName)
                .resizable()
                .scaledToFit()
                .opacity(blinking ? 1 : 0)
        }
        .frame(width: width, height: size)
        .modifier(
            MascotIdleMotionModifier(
                enabled: idleMotionEnabled,
                disappointed: disappointed,
                sizeScale: size / 220
            )
        )
        .onAppear {
            isOnScreen = true
            scheduleBlinkingIfNeeded()
        }
        .onDisappear {
            isOnScreen = false
            blinking = false
        }
        .onChange(of: mascotId) { _, _ in
            blinking = false
            scheduleBlinkingIfNeeded()
        }
        .onChange(of: mood) { _, _ in
            blinking = false
            scheduleBlinkingIfNeeded()
        }
        .onChange(of: animated) { _, _ in
            blinking = false
            scheduleBlinkingIfNeeded()
        }
    }

    private func scheduleBlinkingIfNeeded() {
        guard animated, isOnScreen else { return }
        scheduleNextBlink(after: 2.6 + Double.random(in: 0...2.6))
    }

    private func scheduleNextBlink(after delay: TimeInterval) {
        guard animated, isOnScreen else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard animated, isOnScreen else { return }
            blinking = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                guard animated, isOnScreen else { return }
                blinking = false
                if Double.random(in: 0...1) < 0.25 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                        guard animated, isOnScreen else { return }
                        blinking = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
                            blinking = false
                            scheduleNextBlink(after: 2.6 + Double.random(in: 0...2.6))
                        }
                    }
                } else {
                    scheduleNextBlink(after: 2.6 + Double.random(in: 0...2.6))
                }
            }
        }
    }
}

/// Matches web `.mascot-alive` / `.mascot-alive--disappointed` (`styles/globals.css`).
private struct MascotIdleMotionModifier: ViewModifier {
    let enabled: Bool
    let disappointed: Bool
    let sizeScale: CGFloat

    func body(content: Content) -> some View {
        if enabled {
            TimelineView(BatteryEfficientAnimation.timelineSchedule) { timeline in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                let duration = disappointed ? 5.0 : 4.2
                let progress = (elapsed.truncatingRemainder(dividingBy: duration)) / duration
                let motion = MascotIdleMotion.sample(
                    progress: progress,
                    disappointed: disappointed,
                    sizeScale: sizeScale
                )

                content
                    .offset(y: motion.y)
                    .rotationEffect(.degrees(motion.degrees), anchor: .bottom)
            }
        } else {
            content
        }
    }
}

enum MascotIdleMotion {
    static func sample(progress: Double, disappointed: Bool, sizeScale: CGFloat) -> (y: CGFloat, degrees: Double) {
        if disappointed {
            let y = interpolate(progress, keyframes: [(0, 0), (0.5, -2), (1, 0)]) * sizeScale
            let degrees = interpolate(progress, keyframes: [(0, 0), (0.5, -0.5), (1, 0)])
            return (y, degrees)
        }

        let y = interpolate(progress, keyframes: [(0, 0), (0.3, -5), (0.6, -1), (1, 0)]) * sizeScale
        let degrees = interpolate(progress, keyframes: [(0, 0), (0.3, -1), (0.6, 0.9), (1, 0)])
        return (y, degrees)
    }

    static func interpolate(_ progress: Double, keyframes: [(Double, Double)]) -> CGFloat {
        guard progress >= 0, progress <= 1, keyframes.count >= 2 else { return 0 }

        if progress <= keyframes[0].0 {
            return CGFloat(keyframes[0].1)
        }
        if progress >= keyframes[keyframes.count - 1].0 {
            return CGFloat(keyframes[keyframes.count - 1].1)
        }

        for index in 0..<(keyframes.count - 1) {
            let start = keyframes[index]
            let end = keyframes[index + 1]
            guard progress >= start.0, progress <= end.0 else { continue }
            let span = end.0 - start.0
            guard span > 0 else { return CGFloat(start.1) }
            let local = (progress - start.0) / span
            return CGFloat(start.1 + (end.1 - start.1) * local)
        }

        return 0
    }
}
