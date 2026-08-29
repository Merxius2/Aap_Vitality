import SwiftUI

struct ThemePreviewBar: View {
    let theme: AppThemeDefinition
    var height: CGFloat = 80

    var body: some View {
        Group {
            if theme.previewStyle == "flat" {
                HStack(spacing: 0) {
                    swatch(theme.previewFrom)
                    swatch(theme.previewVia)
                    if let quaternary = theme.previewQuaternary {
                        swatch(quaternary)
                    }
                    swatch(theme.previewTo)
                }
            } else {
                LinearGradient(
                    colors: [theme.previewFrom, theme.previewVia, theme.previewTo],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private func swatch(_ color: Color) -> some View {
        Rectangle().fill(color)
    }
}
