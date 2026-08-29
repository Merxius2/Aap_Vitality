import SwiftUI

struct MedalCardView: View {
    @EnvironmentObject private var preferences: UserPreferencesService
    @Environment(\.appIsDark) private var appIsDark
    let medal: EvaluatedMedal
    var shimmerPlus: Bool = false

    @State private var showTooltip = false

    private var accentColor: Color {
        ThemeVisualProfiles.profile(
            code: preferences.themeCode,
            isDark: appIsDark
        ).displayPrimary
    }

    private var showProgress: Bool {
        !medal.earned && medal.progress?.percent != nil
    }

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: 12) {
                MedalIconView(id: medal.id, tier: medal.tier, earned: medal.earned, size: 48)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(SwimMedalCopy.title(for: medal.id, t: preferences.translations))
                            .themeFont(.subheadline, weight: .semibold)
                            .foregroundStyle(medal.earned ? .primary : .secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .layoutPriority(1)
                    }

                    Text(SwimMedalCopy.description(for: medal.id, t: preferences.translations))
                        .themeFont(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if showProgress, let progress = medal.progress {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(progressSummary(progress))
                                    .themeFont(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(progress.percent)%")
                                    .themeFont(.caption2, weight: .semibold)
                                    .foregroundStyle(accentColor)
                                    .fixedSize()
                            }
                            MedalProgressBar(percent: progress.percent, tint: accentColor)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { showTooltip.toggle() }
                        .popover(isPresented: $showTooltip, arrowEdge: .top) {
                            MedalProgressTooltip(progress: progress)
                                .presentationCompactAdaptation(.popover)
                        }
                    }

                    if medal.earned, let earnedAt = medal.earnedAt {
                        Text(preferences.t("medals.earnedOn", params: [
                            "date": SwimFormatters.formatDateLong(earnedAt)
                        ]))
                            .themeFont(.caption2, weight: .medium)
                            .foregroundStyle(accentColor)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if medal.earned, !medal.periods.isEmpty {
                        Text(SwimMedalCopy.formatPeriods(
                            medal.periods,
                            t: preferences.translations,
                            locale: preferences.locale
                        ))
                            .themeFont(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, medal.earned ? 20 : 0)
            .overlay(alignment: .topLeading) {
                if medal.earned {
                    Text(preferences.t("medals.earned"))
                        .themeFont(.caption2, weight: .bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(tierColor(medal.tier).opacity(0.2), in: Capsule())
                        .foregroundStyle(tierColor(medal.tier))
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(cardBorderColor, lineWidth: medal.earned ? 2 : 1)
                .opacity(medal.earned ? 1 : 0.7)
        }
        .background {
            if medal.earned {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tierColor(medal.tier).opacity(0.06))
            }
        }
        .overlay {
            if medal.earned && shimmerPlus {
                MedalShineOverlay(tier: medal.tier)
            }
        }
        .opacity(medal.earned ? 1 : 0.88)
        .saturation(medal.earned ? 1 : 0.75)
    }

    private var cardBorderColor: Color {
        medal.earned ? tierColor(medal.tier).opacity(0.45) : Color(.separator).opacity(0.5)
    }

    private func progressSummary(_ progress: MedalProgress) -> String {
        let current = formatProgressValue(progress.kind, progress.current)
        let target = formatProgressValue(progress.kind, progress.target)
        return preferences.t("medals.progress.summary", params: [
            "current": current,
            "target": target
        ])
    }

    private func formatProgressValue(_ kind: String, _ value: Int?) -> String {
        guard let value else { return "—" }
        switch kind {
        case "distance":
            return SwimFormatters.formatDistance(value)
        case "duration":
            return SwimFormatters.formatDuration(value)
        case "kcal":
            return "\(value) " + preferences.t("common.kcal")
        case "pace":
            return SwimFormatters.formatPace(value)
        default:
            return String(value)
        }
    }

    private func tierColor(_ tier: String) -> Color {
        switch tier {
        case "gold": return .yellow
        case "silver": return .gray
        default: return .orange
        }
    }
}

struct MedalIconView: View {
    let id: String
    let tier: String
    let earned: Bool
    var size: CGFloat = 40

    private var palette: MedalTierPalette { MedalTierPalette.palette(for: tier) }

    var body: some View {
        ZStack {
            MedalRibbonView(color: palette.ribbon, earned: earned)
                .frame(width: size * 0.55, height: size * 0.35)
                .offset(y: size * 0.42)

            Circle()
                .fill(
                    earned
                        ? LinearGradient(colors: [palette.from, palette.to], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color(.systemGray4), Color(.systemGray5)], startPoint: .top, endPoint: .bottom)
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .strokeBorder(earned ? palette.rim.opacity(0.8) : Color(.systemGray3), lineWidth: 2)
                )

            MedalGlyphView(id: id, earned: earned, size: size * 0.55)

            if !earned {
                Image(systemName: "lock.fill")
                    .font(.system(size: size * 0.22, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(5)
                    .background(Color.black.opacity(0.35), in: Circle())
                    .offset(x: size * 0.28, y: size * 0.28)
            }
        }
        .frame(width: size, height: size * 1.1)
    }
}

private struct MedalRibbonView: View {
    let color: Color
    let earned: Bool

    var body: some View {
        HStack(spacing: 2) {
            RibbonTail()
                .fill(earned ? color : Color(.systemGray3))
                .frame(width: 12, height: 16)
            RibbonTail()
                .fill(earned ? color : Color(.systemGray3))
                .frame(width: 12, height: 16)
                .scaleEffect(x: -1, y: 1)
        }
    }
}

private struct RibbonTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct MedalProgressBar: View {
    let percent: Int
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray5))
                Capsule()
                    .fill(LinearGradient(colors: [tint, Color(red: 0.48, green: 0.36, blue: 1.0)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: proxy.size.width * CGFloat(percent) / 100)
            }
        }
        .frame(height: 6)
    }
}

private struct MedalProgressTooltip: View {
    @EnvironmentObject private var preferences: UserPreferencesService
    let progress: MedalProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .themeFont(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: 240, alignment: .leading)
    }

    private var lines: [String] {
        var result: [String] = []
        result.append(SwimMedalCopy.progressScopeLabel(progress.scope, t: preferences.translations))
        result.append(progressSummary)
        if progress.percent > 0 {
            result.append(preferences.t("medals.progress.percentComplete", params: ["percent": String(progress.percent)]))
        }
        if let best = progress.best, best > 0, best > (progress.current ?? 0) {
            let detail = formatValue(progress.kind, best)
                + (progress.bestPeriod.map { " (\(formatPeriod($0)))" } ?? "")
            result.append(preferences.t("medals.progress.alsoBest", params: ["detail": detail]))
        }
        if progress.kind == "pace" && progress.current == nil {
            result.append(preferences.t("medals.progress.noPaceYet"))
        }
        return result
    }

    private var progressSummary: String {
        preferences.t("medals.progress.summary", params: [
            "current": formatValue(progress.kind, progress.current),
            "target": formatValue(progress.kind, progress.target)
        ])
    }

    private func formatValue(_ kind: String, _ value: Int?) -> String {
        guard let value else { return "—" }
        switch kind {
        case "distance": return SwimFormatters.formatDistance(value)
        case "duration": return SwimFormatters.formatDuration(value)
        case "kcal": return "\(value) " + preferences.t("common.kcal")
        case "pace": return SwimFormatters.formatPace(value)
        default: return String(value)
        }
    }

    private func formatPeriod(_ period: String) -> String {
        SwimMedalCopy.formatPeriods([period], t: preferences.translations, locale: preferences.locale)
    }
}

private struct MedalShineOverlay: View {
    let tier: String
    @Environment(\.appAnimationsPaused) private var animationsPaused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if animationsPaused || reduceMotion {
            EmptyView()
        } else {
            TimelineView(BatteryEfficientAnimation.timelineSchedule) { timeline in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                let cycle = 2.8
                let progress = (elapsed.truncatingRemainder(dividingBy: cycle)) / cycle
                let phase = -1 + progress * 2.4

                GeometryReader { proxy in
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.35), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: proxy.size.width * 0.35)
                    .offset(x: proxy.size.width * phase)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .allowsHitTesting(false)
            }
        }
    }
}

struct MonthlyMedalTileView: View {
    @EnvironmentObject private var preferences: UserPreferencesService
    let state: MonthlyChallengeState
    var compact: Bool = false
    var size: CGFloat = 40

    var body: some View {
        VStack(spacing: 6) {
            MonthlyMedalIconView(tier: state.tier, size: size, muted: state.tier == nil)

            if compact {
                Text(SwimMonthlyChallengeFormatters.monthShortLabel(state.monthKey, locale: preferences.locale))
                    .themeFont(.caption2, weight: .medium)

                if state.isPreview {
                    Text(preferences.t("monthlyChallenges.previewLabel"))
                        .themeFont(.caption2, weight: .semibold)
                        .foregroundStyle(.orange)
                }

                if let tier = state.tier {
                    Text(SwimMonthlyChallengeFormatters.tierLabel(tier, t: preferences.translations))
                        .themeFont(.caption2, weight: .semibold)
                        .foregroundStyle(Color("BrandBlue"))
                } else if state.challenges.contains(where: { $0.current > 0 }) {
                    Text(preferences.t("monthlyChallenges.inProgress"))
                        .themeFont(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("—")
                        .themeFont(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(compact ? 8 : 0)
        .background(compact ? Color(.secondarySystemBackground) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct MonthlyMedalIconView: View {
    let tier: String?
    var size: CGFloat = 40
    var muted: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(background)
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                )
            Image(systemName: "seal.fill")
                .font(.system(size: size * 0.42))
                .foregroundStyle(foreground)
        }
    }

    private var background: some ShapeStyle {
        if muted || tier == nil {
            return AnyShapeStyle(Color(.systemGray5))
        }
        switch tier {
        case "gold":
            return AnyShapeStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
        case "silver":
            return AnyShapeStyle(LinearGradient(colors: [.gray, Color(white: 0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
        default:
            return AnyShapeStyle(LinearGradient(colors: [Color(red: 0.75, green: 0.45, blue: 0.15), .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }

    private var foreground: Color {
        muted || tier == nil ? Color(.systemGray) : .white
    }
}

struct MonthlyChallengeHistoryView: View {
    @EnvironmentObject private var viewModel: SwimViewModel
    @EnvironmentObject private var preferences: UserPreferencesService
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())

    var body: some View {
        let history = viewModel.monthlyChallengeHistory

        if !history.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(preferences.t("monthlyChallenges.historyTitle"))
                            .themeFont(.caption, weight: .bold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(preferences.t("monthlyChallenges.historySubtitle"))
                            .themeFont(.caption2)
                            .foregroundStyle(.secondary)
                        if viewModel.cheats.previewMonthlyMedals {
                            Text(preferences.t("monthlyChallenges.previewActive"))
                                .themeFont(.caption2, weight: .medium)
                                .foregroundStyle(.orange)
                        }
                    }
                    Spacer()
                    if years(from: history).count > 1 {
                        Picker(preferences.t("monthlyChallenges.yearLabel"), selection: $selectedYear) {
                            ForEach(years(from: history), id: \.self) { year in
                                Text(String(year)).tag(year)
                            }
                        }
                        .pickerStyle(.menu)
                    } else if let year = years(from: history).first {
                        Text(String(year))
                            .themeFont(.caption, weight: .semibold)
                            .foregroundStyle(.secondary)
                    }
                }

                let activeYear = years(from: history).contains(selectedYear)
                    ? selectedYear
                    : (years(from: history).first ?? selectedYear)
                let months = history
                    .filter { $0.monthKey.hasPrefix("\(activeYear)-") }
                    .sorted { $0.monthKey > $1.monthKey }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(months, id: \.monthKey) { entry in
                        MonthlyMedalTileView(state: entry, compact: true, size: 36)
                    }
                }
            }
        }
    }

    private func years(from history: [MonthlyChallengeState]) -> [Int] {
        Array(Set(history.compactMap { Int($0.monthKey.prefix(4)) })).sorted(by: >)
    }
}
