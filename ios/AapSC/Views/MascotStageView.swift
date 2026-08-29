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
                    Color.white.opacity(0.9),
                    Color.white.opacity(0.68),
                    Color.white.opacity(0.25),
                    Color.white.opacity(0.1),
                ],
                startPoint: UnitPoint(x: 0.05, y: 0.1),
                endPoint: UnitPoint(x: 0.95, y: 0.9)
            )
            LinearGradient(
                colors: [.clear, Color(red: 0.12, green: 0.23, blue: 0.54, opacity: 0.12)],
                startPoint: .top,
                endPoint: .bottom
            )
        case "fins":
            LinearGradient(
                colors: [
                    Color.white.opacity(0.92),
                    Color.white.opacity(0.72),
                    Color.white.opacity(0.28),
                    Color.white.opacity(0.12),
                ],
                startPoint: UnitPoint(x: 0.05, y: 0.1),
                endPoint: UnitPoint(x: 0.95, y: 0.9)
            )
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.15)],
                startPoint: .top,
                endPoint: .bottom
            )
        default:
            LinearGradient(
                colors: [
                    Color.white.opacity(0.92),
                    Color.white.opacity(0.7),
                    Color.white.opacity(0.28),
                    Color.white.opacity(0.1),
                ],
                startPoint: UnitPoint(x: 0.05, y: 0.1),
                endPoint: UnitPoint(x: 0.95, y: 0.9)
            )
            LinearGradient(
                colors: [.clear, Color(red: 0.024, green: 0.31, blue: 0.23, opacity: 0.1)],
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
                    Color(red: 0.82, green: 0.94, blue: 1.0),
                    Color(red: 0.55, green: 0.82, blue: 0.98),
                    Color(red: 0.20, green: 0.55, blue: 0.86),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "fins":
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.09, blue: 0.16),
                    Color(red: 0.04, green: 0.24, blue: 0.34),
                    Color(red: 0.08, green: 0.45, blue: 0.52),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            LinearGradient(
                colors: [
                    Color(red: 0.88, green: 0.98, blue: 0.94),
                    Color(red: 0.74, green: 0.93, blue: 0.86),
                    Color(red: 0.47, green: 0.78, blue: 0.66),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
