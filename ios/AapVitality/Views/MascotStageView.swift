import SwiftUI

struct MascotStageView<Content: View>: View {
    let mascotId: String
    var compact: Bool = false
    @ViewBuilder let content: () -> Content

    private var stageId: String {
        MascotPresentation.stageId(for: mascotId)
    }

    private var cornerRadius: CGFloat {
        compact ? 14 : 18
    }

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(compact ? 12 : 16)
            .background {
                ZStack {
                    stagePhoto
                    stageOverlay
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(MascotPresentation.stageBorderColor(mascotId: stageId), lineWidth: 1)
            )
    }

    @ViewBuilder
    private var stagePhoto: some View {
        if let imageName = MascotConstants.stageBackgroundImageName(stageId) {
            Image(imageName)
                .resizable()
                .scaledToFill()
        } else {
            fallbackGradient
        }
    }

    @ViewBuilder
    private var stageOverlay: some View {
        switch stageId {
        case "flo":
            LinearGradient(
                colors: [
                    Color.white.opacity(0.78),
                    Color.white.opacity(0.42),
                    Color.white.opacity(0.12),
                    Color.clear,
                ],
                startPoint: UnitPoint(x: 0.05, y: 0.05),
                endPoint: UnitPoint(x: 0.95, y: 0.95)
            )
            LinearGradient(
                colors: [.clear, Color(red: 0.08, green: 0.45, blue: 0.55, opacity: 0.14)],
                startPoint: .top,
                endPoint: .bottom
            )
        case "fins":
            LinearGradient(
                colors: [
                    Color.white.opacity(0.55),
                    Color.white.opacity(0.22),
                    Color.clear,
                    Color.black.opacity(0.18),
                ],
                startPoint: UnitPoint(x: 0.1, y: 0.05),
                endPoint: UnitPoint(x: 0.9, y: 0.95)
            )
            LinearGradient(
                colors: [.clear, Color(red: 0.55, green: 0.18, blue: 0.08, opacity: 0.18)],
                startPoint: .top,
                endPoint: .bottom
            )
        default:
            LinearGradient(
                colors: [
                    Color.white.opacity(0.82),
                    Color.white.opacity(0.45),
                    Color.white.opacity(0.12),
                    Color.clear,
                ],
                startPoint: UnitPoint(x: 0.05, y: 0.05),
                endPoint: UnitPoint(x: 0.95, y: 0.95)
            )
            LinearGradient(
                colors: [.clear, Color(red: 0.12, green: 0.42, blue: 0.28, opacity: 0.12)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    @ViewBuilder
    private var fallbackGradient: some View {
        switch stageId {
        case "flo":
            LinearGradient(
                colors: [
                    Color(red: 0.78, green: 0.93, blue: 0.98),
                    Color(red: 0.42, green: 0.78, blue: 0.82),
                    Color(red: 0.18, green: 0.55, blue: 0.62),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "fins":
            LinearGradient(
                colors: [
                    Color(red: 0.18, green: 0.10, blue: 0.28),
                    Color(red: 0.45, green: 0.18, blue: 0.16),
                    Color(red: 0.92, green: 0.48, blue: 0.18),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.97, blue: 0.86),
                    Color(red: 0.72, green: 0.90, blue: 0.62),
                    Color(red: 0.35, green: 0.72, blue: 0.48),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
