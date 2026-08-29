import SwiftUI

struct ConfettiView: View {
    @Environment(\.appAnimationsPaused) private var animationsPaused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let particleCount = 72
    private let colors: [Color] = [
        .red, .orange, .yellow, .green, .mint, .cyan, .blue, .indigo, .purple, .pink
    ]

    var body: some View {
        if animationsPaused || reduceMotion {
            EmptyView()
        } else {
            TimelineView(BatteryEfficientAnimation.timelineSchedule) { timeline in
                Canvas { context, size in
                    let elapsed = timeline.date.timeIntervalSinceReferenceDate
                    for index in 0..<particleCount {
                        drawParticle(index: index, elapsed: elapsed, in: &context, size: size)
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func drawParticle(
        index: Int,
        elapsed: TimeInterval,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let seed = Double(index + 1)
        let startX = size.width * (0.15 + 0.7 * pseudoRandom(seed * 1.31))
        let horizontalDrift = sin(elapsed * (1.2 + pseudoRandom(seed * 2.17) * 1.5) + seed) * 32
        let fallSpeed = 95 + pseudoRandom(seed * 3.41) * 120
        let phase = elapsed * fallSpeed + seed * 44
        let y = phase.truncatingRemainder(dividingBy: Double(size.height + 80)) - 40
        let x = startX + horizontalDrift

        let rotation = Angle.degrees(
            elapsed * (140 + pseudoRandom(seed * 4.59) * 200) + seed * 36
        )
        let width = 6 + pseudoRandom(seed * 5.73) * 7
        let height = 10 + pseudoRandom(seed * 6.87) * 9
        let color = colors[Int(seed) % colors.count]
        let isCircle = pseudoRandom(seed * 7.91) > 0.65

        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: x, y: y)
        transform = transform.rotated(by: rotation.radians)

        let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
        var path: Path
        if isCircle {
            path = Path(ellipseIn: rect)
        } else {
            path = Path(roundedRect: rect, cornerRadius: 1.5)
        }
        path = path.applying(transform)

        context.fill(path, with: .color(color.opacity(0.9)))
    }

    private func pseudoRandom(_ seed: Double) -> Double {
        let value = sin(seed * 12.9898) * 43_758.5453
        return value - floor(value)
    }
}
