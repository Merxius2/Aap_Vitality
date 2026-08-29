import SwiftUI

enum MascotSpeechTailDirection {
    case left
    case bottom
}

struct MascotSpeechBubbleView: View {
    let message: String
    var tone: MascotBubbleTone = .default
    var mascotId: String = "flip"
    var tail: MascotSpeechTailDirection = .left
    @Environment(\.appIsDark) private var appIsDark

    private var resolvedColorScheme: ColorScheme {
        appIsDark ? .dark : .light
    }

    var body: some View {
        if message.isEmpty {
            EmptyView()
        } else {
            let style = MascotPresentation.speechBubbleStyle(
                mascotId: mascotId,
                tone: tone,
                colorScheme: resolvedColorScheme
            )

            ZStack(alignment: tail == .bottom ? .bottom : .leading) {
                HStack(alignment: .top, spacing: 12) {
                    toneIcon
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(appIsDark ? 0.08 : 0.8))
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white.opacity(appIsDark ? 0.1 : 0.6), lineWidth: 1)
                                )
                        )

                    Text(message)
                        .themeFont(.subheadline, weight: .medium)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(style.fill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(style.border, lineWidth: 1.5)
                        )
                        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
                )

                SpeechBubbleTail(style: style, direction: tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var toneIcon: some View {
        switch tone {
        case .reward:
            Image(systemName: "medal.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.yellow)
        case .tip:
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.teal)
        case .levelUp:
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.green)
        case .thinking:
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color("BrandBlue"))
                .symbolEffect(.pulse)
        case .disappointed:
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.orange)
        case .default:
            Image(systemName: "water.waves")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color("BrandBlue"))
        }
    }
}

private struct SpeechBubbleTail: View {
    let style: MascotSpeechBubbleStyle
    let direction: MascotSpeechTailDirection

    var body: some View {
        Rectangle()
            .fill(style.fill)
            .frame(width: 14, height: 14)
            .overlay(
                Rectangle()
                    .stroke(style.border, lineWidth: 1.5)
            )
            .rotationEffect(.degrees(45))
            .offset(tailOffset)
    }

    private var tailOffset: CGSize {
        switch direction {
        case .left:
            return CGSize(width: -7, height: 0)
        case .bottom:
            return CGSize(width: 0, height: 10)
        }
    }
}
