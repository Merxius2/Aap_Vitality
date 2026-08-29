import SwiftUI
import Charts

struct RecordsSectionView: View {
    @EnvironmentObject private var preferences: UserPreferencesService
    let records: PersonalRecords?

    var body: some View {
        if let records {
            let entries = buildEntries(records)
            if !entries.isEmpty {
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(preferences.t("records.title"), systemImage: "trophy.fill")
                            .themeFont(.headline, weight: .semibold)
                            .foregroundStyle(.orange)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(entries, id: \.title) { entry in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.title)
                                        .themeFont(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(entry.value)
                                        .themeFont(.headline, weight: .semibold)
                                        .foregroundStyle(entry.color)
                                    Text(SwimFormatters.formatDateShort(entry.date))
                                        .themeFont(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
            }
        }
    }

    private struct RecordEntry {
        let title: String
        let value: String
        let date: String
        let color: Color
    }

    private func buildEntries(_ records: PersonalRecords) -> [RecordEntry] {
        var entries: [RecordEntry] = []
        if let record = records.longestDistance {
            entries.append(RecordEntry(title: preferences.t("records.longestDistance"), value: SwimFormatters.formatDistance(Int(record.value)), date: record.date, color: .blue))
        }
        if let record = records.fastestPace {
            entries.append(RecordEntry(title: preferences.t("records.fastestPace"), value: SwimFormatters.formatPace(Int(record.value)), date: record.date, color: .teal))
        }
        if let record = records.mostActiveCalories {
            entries.append(RecordEntry(title: preferences.t("records.mostCalories"), value: "\(Int(record.value)) " + preferences.t("common.kcal"), date: record.date, color: .red))
        }
        if let record = records.mostTotalCalories {
            entries.append(RecordEntry(title: preferences.t("records.mostTotalCalories"), value: "\(Int(record.value)) " + preferences.t("common.kcal"), date: record.date, color: .orange))
        }
        if let record = records.mostLaps {
            entries.append(RecordEntry(title: preferences.t("records.mostLaps"), value: "\(Int(record.value))", date: record.date, color: .purple))
        }
        if let record = records.longestDuration {
            entries.append(RecordEntry(title: preferences.t("records.longestDuration"), value: SwimFormatters.formatDuration(Int(record.value)), date: record.date, color: .yellow))
        }
        if let record = records.highestHeartRate {
            entries.append(RecordEntry(title: preferences.t("records.highestHeartRate"), value: "\(Int(record.value)) " + preferences.t("common.bpm"), date: record.date, color: .pink))
        }
        return entries
    }
}

struct SessionFeedbackCard: View {
    @EnvironmentObject private var viewModel: SwimViewModel
    @EnvironmentObject private var preferences: UserPreferencesService
    let feedback: SessionFeedbackSummary
    var titleKey: String = "feedback.title"
    var isLoading: Bool = false

    private var mascotMessage: String {
        if isLoading { return preferences.t("mascot.thinking") }
        if !feedback.coachMessage.isEmpty { return feedback.coachMessage }
        if !feedback.motivation.isEmpty { return feedback.motivation }
        if !feedback.tip.isEmpty { return feedback.tip }
        if let first = feedback.insights.first { return first }
        let template = preferences.t(MascotConstants.cheerKey(viewModel.mascotId))
        return applyMessagePlaceholders(template)
    }

    private var bubbleTone: MascotBubbleTone {
        if feedback.mascotMood == "disappointed" { return .disappointed }
        return MascotPresentation.resolveBubbleTone(
            loading: isLoading,
            coachMessage: feedback.coachMessage,
            motivation: feedback.motivation,
            tip: feedback.tip,
            badges: feedback.badges,
            benchmarkLevel: feedback.benchmarkLevel,
            message: mascotMessage
        )
    }

    private var hasContent: Bool {
        isLoading
            || !feedback.insights.isEmpty
            || !feedback.badges.isEmpty
            || !feedback.coachMessage.isEmpty
            || !feedback.motivation.isEmpty
            || !feedback.highlights.isEmpty
            || !feedback.tip.isEmpty
    }

    var body: some View {
        if !hasContent {
            EmptyView()
        } else {
            Card {
                VStack(alignment: .leading, spacing: 16) {
                    MascotCoachView(
                        mascotId: viewModel.mascotId,
                        message: mascotMessage,
                        mood: feedback.mascotMood,
                        bubbleTone: bubbleTone,
                        showStage: true,
                        size: 170,
                        animated: false,
                        layout: .stacked
                    )
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .themeFont(.body, weight: .semibold)
                                .foregroundStyle(Color("BrandBlue"))
                            Text(preferences.t(titleKey))
                                .themeFont(.headline, weight: .semibold)
                            if feedback.benchmarkLevel != .unknown {
                                Text(SwimBenchmarks.levelLabel(feedback.benchmarkLevel, t: preferences.translations))
                                    .themeFont(.caption2, weight: .semibold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.12), in: Capsule())
                                    .foregroundStyle(.blue)
                            }
                            if feedback.aiEnhanced {
                                Label("AI", systemImage: "cpu")
                                    .themeFont(.caption2, weight: .semibold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.purple.opacity(0.12), in: Capsule())
                                    .foregroundStyle(.purple)
                            }
                        }

                        if isLoading {
                            Text(preferences.t("feedback.aiLoading"))
                                .themeFont(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            if !feedback.highlights.isEmpty {
                                LazyVGrid(
                                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                                    spacing: 8
                                ) {
                                    ForEach(feedback.highlights) { item in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.label)
                                                .themeFont(.caption2, weight: .semibold)
                                                .foregroundStyle(.secondary)
                                                .textCase(.uppercase)
                                                .tracking(0.8)
                                            Text(item.value)
                                                .themeFont(.subheadline, weight: .semibold)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(Color(.secondarySystemBackground).opacity(0.8), in: RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 1)
                                        )
                                    }
                                }
                            }

                            if !feedback.motivation.isEmpty && !feedback.coachMessage.isEmpty {
                                Text(feedback.motivation)
                                    .themeFont(.subheadline, weight: .medium)
                                    .italic()
                                    .foregroundStyle(Color("BrandBlue"))
                            }

                            if !feedback.badges.isEmpty {
                                FlowLayout(spacing: 8) {
                                    ForEach(feedback.badges, id: \.self) { badge in
                                        Label(badge, systemImage: "sparkles")
                                            .themeFont(.caption, weight: .semibold)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.orange.opacity(0.15), in: Capsule())
                                            .foregroundStyle(Color.orange.opacity(0.9))
                                    }
                                }
                            }

                            if !feedback.insights.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Divider()
                                    ForEach(feedback.insights, id: \.self) { insight in
                                        let positive = SwimFeedback.isPositiveInsight(insight)
                                        HStack(alignment: .top, spacing: 8) {
                                            Image(systemName: positive ? "arrow.up.right" : "arrow.down.right")
                                                .themeFont(.caption, weight: .semibold)
                                                .foregroundStyle(positive ? .green : .secondary)
                                                .padding(.top, 2)
                                            Text(insight)
                                                .themeFont(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }

                            if !feedback.tip.isEmpty {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "lightbulb.fill")
                                        .themeFont(.body)
                                        .foregroundStyle(Color("BrandBlue"))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(preferences.t("feedback.tipTitle"))
                                            .themeFont(.caption2, weight: .semibold)
                                            .foregroundStyle(Color("BrandBlue"))
                                            .textCase(.uppercase)
                                            .tracking(0.8)
                                        Text(feedback.tip)
                                            .themeFont(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color("BrandBlue").opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(Color("BrandBlue").opacity(0.2), lineWidth: 1)
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private func applyMessagePlaceholders(_ template: String) -> String {
        let name = viewModel.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = name.isEmpty ? preferences.t("settings.swimmerNamePlaceholder") : name
        return template.replacingOccurrences(of: "{name}", with: displayName)
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

struct MonthlyChallengesCardView: View {
    @EnvironmentObject private var viewModel: SwimViewModel
    @EnvironmentObject private var preferences: UserPreferencesService

    private let tierSteps = ["bronze", "silver", "gold"]

    var body: some View {
        let state = viewModel.currentMonthlyChallenges
        let monthKey = state.monthKey
        let gameplay = MascotConstants.gameplay(viewModel.mascotId)
        let currentTierIndex = state.tier.flatMap { tierSteps.firstIndex(of: $0) } ?? -1
        let rerollAvailable = SwimMonthlyChallenges.hasRerollAvailability(
            monthKey: monthKey,
            rerolls: viewModel.monthlyChallengeRerolls,
            freeLimit: gameplay.freeMonthlyRerolls
        )

        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 8) {
                        MonthlyMedalIconView(tier: state.tier, size: 64, muted: state.tier == nil)
                        if let tier = state.tier {
                            Text(SwimMonthlyChallengeFormatters.tierLabel(tier, t: preferences.translations))
                                .themeFont(.caption2, weight: .semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(tierColor(tier).opacity(0.2), in: Capsule())
                        }
                        HStack(spacing: 6) {
                            ForEach(Array(tierSteps.enumerated()), id: \.offset) { index, tier in
                                Circle()
                                    .fill(index <= currentTierIndex ? tierColor(tier) : Color(.systemGray4))
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(preferences.t("monthlyChallenges.title"))
                            .themeFont(.headline, weight: .semibold)
                        Text(SwimMonthlyChallengeFormatters.monthLabel(monthKey, locale: preferences.locale))
                            .themeFont(.caption)
                            .foregroundStyle(.secondary)
                        Text(preferences.t("monthlyChallenges.subtitle"))
                            .themeFont(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(Array(state.challenges.enumerated()), id: \.element.id) { index, challenge in
                    challengeRow(
                        challenge: challenge,
                        index: index,
                        monthKey: monthKey,
                        gameplay: gameplay
                    )
                }

                if !rerollAvailable {
                    Text(preferences.t("monthlyChallenges.rerollUsed"))
                        .themeFont(.caption2)
                        .foregroundStyle(.secondary)
                }

                Divider()

                HStack(spacing: 8) {
                    ForEach(Array(tierSteps.enumerated()), id: \.offset) { index, tier in
                        let earned = currentTierIndex >= index
                        let isCurrent = state.tier == tier
                        Text(SwimMonthlyChallengeFormatters.tierLabel(tier, t: preferences.translations))
                            .themeFont(.caption2, weight: .medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                isCurrent
                                    ? Color("BrandBlue").opacity(0.12)
                                    : earned
                                        ? Color.green.opacity(0.12)
                                        : Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                    }
                }

                Text(preferences.t("monthlyChallenges.tierHint"))
                    .themeFont(.caption2)
                    .foregroundStyle(.secondary)

                if let requiredTier = gameplay.requiredMonthlyTier {
                    Text(preferences.t("monthlyChallenges.coachRequirement", params: [
                        "name": MascotConstants.displayName(viewModel.mascotId, t: preferences.translations),
                        "tier": SwimMonthlyChallengeFormatters.tierLabel(requiredTier, t: preferences.translations)
                    ]))
                        .themeFont(.caption2)
                        .foregroundStyle(.red.opacity(0.85))
                }
            }
        }
    }

    @ViewBuilder
    private func challengeRow(
        challenge: MonthlyChallenge,
        index: Int,
        monthKey: String,
        gameplay: MascotGameplay
    ) -> some View {
        let pct = challenge.target > 0
            ? min(100, Int(round(Double(challenge.current) / Double(challenge.target) * 100)))
            : 0
        let showReroll = SwimMonthlyChallenges.canRerollMonthlyChallenge(
            sessions: viewModel.sessions,
            monthKey: monthKey,
            tierIndex: index,
            rerolls: viewModel.monthlyChallengeRerolls,
            intensity: gameplay.challengeIntensity,
            freeLimit: gameplay.freeMonthlyRerolls
        )

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(SwimMonthlyChallengeFormatters.challengeTypeLabel(challenge.type, t: preferences.translations))
                    .themeFont(.subheadline, weight: .medium)
                Spacer()
                if showReroll {
                    Button {
                        viewModel.rerollMonthlyChallenge(monthKey: monthKey, tierIndex: index)
                    } label: {
                        Label(preferences.t("monthlyChallenges.reroll"), systemImage: "shuffle")
                            .themeFont(.caption2, weight: .medium)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
                if challenge.completed {
                    Text(preferences.t("monthlyChallenges.done"))
                        .themeFont(.caption2, weight: .bold)
                        .foregroundStyle(.green)
                        .textCase(.uppercase)
                }
            }

            Text(SwimMonthlyChallengeFormatters.formatChallengeTarget(challenge.type, challenge.target, t: preferences.translations))
                .themeFont(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("\(SwimMonthlyChallengeFormatters.formatChallengeValue(challenge.type, challenge.current, t: preferences.translations)) / \(SwimMonthlyChallengeFormatters.formatChallengeValue(challenge.type, challenge.target, t: preferences.translations))")
                    .themeFont(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(pct)%")
                    .themeFont(.caption2, weight: .semibold)
                    .foregroundStyle(Color("BrandBlue"))
            }

            ProgressView(value: Double(min(challenge.current, challenge.target)), total: Double(max(challenge.target, 1)))
                .tint(challenge.completed ? .green : Color("BrandBlue"))
        }
        .padding(10)
        .background(
            challenge.completed ? Color.green.opacity(0.08) : Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 10)
        )
    }

    private func tierColor(_ tier: String) -> Color {
        switch tier {
        case "gold": return .yellow
        case "silver": return .gray
        default: return .orange
        }
    }
}

enum SwimChartPalette {
    static let segmentColors: [Color] = [
        Color(red: 0.925, green: 0.282, blue: 0.600),
        Color(red: 0.063, green: 0.725, blue: 0.506),
        Color(red: 0.231, green: 0.510, blue: 0.965),
        Color(red: 0.545, green: 0.361, blue: 0.965),
        Color(red: 0.961, green: 0.620, blue: 0.043),
        Color(red: 0.024, green: 0.714, blue: 0.831),
        Color(red: 0.078, green: 0.722, blue: 0.651),
        Color(red: 0.937, green: 0.267, blue: 0.267),
        Color(red: 0.976, green: 0.451, blue: 0.086),
    ]

    private static let strokeOrder = [
        "mixedM", "breaststrokeM", "freestyleM", "backstrokeM", "butterflyM"
    ]

    static func color(for strokeId: String) -> Color {
        let index = strokeOrder.firstIndex(of: strokeId) ?? 0
        return segmentColors[index % segmentColors.count]
    }
}

struct ChartSelectionFooter: View {
    let title: String
    let value: String
    var secondaryValue: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .themeFont(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .themeFont(.caption, weight: .semibold)
            }
            if let secondaryValue {
                Text(secondaryValue)
                    .themeFont(.caption, weight: .semibold)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ChartXLabelSelectionModifier: ViewModifier {
    @Binding var selection: String?

    func body(content: Content) -> some View {
        content.chartOverlay { proxy in
            GeometryReader { geometry in
                if let plotFrame = proxy.plotFrame {
                    let plotArea = geometry[plotFrame]
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .frame(width: plotArea.width, height: plotArea.height)
                        .position(x: plotArea.midX, y: plotArea.midY)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { gesture in
                                    let x = gesture.location.x - plotArea.minX
                                    guard x >= 0, x <= plotArea.width else { return }
                                    if let label: String = proxy.value(atX: x, as: String.self) {
                                        selection = label
                                    }
                                }
                        )
                }
            }
        }
    }
}

extension View {
    @ViewBuilder
    func chartXLabelSelection(_ selection: Binding<String?>, enabled: Bool = true) -> some View {
        if enabled {
            modifier(ChartXLabelSelectionModifier(selection: selection))
        } else {
            self
        }
    }
}

struct StrokeDonutChart: View {
    @EnvironmentObject private var preferences: UserPreferencesService
    @Environment(\.appIsDark) private var appIsDark
    let slices: [StrokeChartSlice]

    @State private var selectedValue: Int?

    private var filtered: [StrokeChartSlice] {
        slices.filter { $0.value > 0 }
    }

    private var total: Int {
        filtered.map(\.value).reduce(0, +)
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                Text(preferences.t("progress.strokeMix"))
                    .themeFont(.headline, weight: .semibold)

                ZStack {
                    Chart(filtered) { slice in
                        SectorMark(
                            angle: .value("Meters", slice.value),
                            innerRadius: .ratio(0.70),
                            outerRadius: .ratio(0.98),
                            angularInset: 2
                        )
                        .foregroundStyle(SwimChartPalette.color(for: slice.id))
                        .opacity(selectedValue == nil || selectedValue == slice.value ? 1 : 0.4)
                    }
                    .chartLegend(.hidden)
                    .chartAngleSelection(value: $selectedValue)

                    VStack(spacing: 4) {
                        Text("M")
                            .themeFont(.caption, weight: .semibold)
                            .foregroundStyle(.secondary)
                            .tracking(3)
                        Text(total.formatted())
                            .themeFont(.title2, weight: .bold)
                            .monospacedDigit()
                    }
                    .frame(width: 88, height: 88)
                    .background {
                        Circle()
                            .fill(centerGradient)
                            .shadow(color: .black.opacity(appIsDark ? 0.3 : 0.1), radius: 10, y: 4)
                    }
                    .allowsHitTesting(false)
                }
                .frame(maxWidth: 280)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .padding(.vertical, 4)

                VStack(spacing: 10) {
                    ForEach(filtered) { slice in
                        let percentage = total > 0 ? Double(slice.value) / Double(total) * 100 : 0
                        HStack(spacing: 10) {
                            Circle()
                                .fill(SwimChartPalette.color(for: slice.id))
                                .frame(width: 12, height: 12)
                            Text(slice.label)
                                .themeFont(.subheadline)
                            Spacer(minLength: 8)
                            Text(SwimFormatters.formatDistance(slice.value))
                                .themeFont(.subheadline, weight: .semibold)
                                .monospacedDigit()
                            Text(String(format: "(%.1f%%)", percentage))
                                .themeFont(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .opacity(selectedValue == nil || selectedValue == slice.value ? 1 : 0.45)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedValue = selectedValue == slice.value ? nil : slice.value
                        }
                    }
                }
            }
        }
    }

    private var centerGradient: LinearGradient {
        if appIsDark {
            return LinearGradient(
                colors: [Color(white: 0.18), Color(white: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: [Color(white: 0.95), Color(white: 0.90)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct BenchmarkBadgeRankingView: View {
    @EnvironmentObject private var preferences: UserPreferencesService
    let label: String
    let percentile: Int
    let vsMedian: String

    var body: some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(label)
                        .themeFont(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(percentile)%")
                        .themeFont(size: 34, weight: .bold)
                    Text(vsMedian == "above"
                        ? preferences.t("benchmark.badges.aboveMedian")
                        : preferences.t("benchmark.badges.belowMedian"))
                        .themeFont(.subheadline, weight: .semibold)
                        .foregroundStyle(vsMedian == "above" ? .green : .orange)
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(vsMedian == "above" ? Color.green : Color.orange)
                        .frame(width: 64, height: 64)
                    Text("\(percentile)%")
                        .themeFont(.headline, weight: .bold)
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

struct SessionCalendarView: View {
    @EnvironmentObject private var preferences: UserPreferencesService
    let sessions: [SwimSession]
    @Binding var selectedDate: String?

    @State private var viewYear: Int
    @State private var viewMonth: Int

    init(sessions: [SwimSession], selectedDate: Binding<String?>) {
        self.sessions = sessions
        self._selectedDate = selectedDate
        let today = Date()
        let calendar = Calendar.current
        _viewYear = State(initialValue: calendar.component(.year, from: today))
        _viewMonth = State(initialValue: calendar.component(.month, from: today))
    }

    var body: some View {
        Card {
            VStack(spacing: 12) {
                HStack {
                    Text(preferences.t("history.calendarTitle"))
                        .themeFont(.headline, weight: .semibold)
                    Spacer()
                    Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                    Text(monthTitle)
                        .themeFont(.subheadline, weight: .semibold)
                        .frame(minWidth: 120)
                    Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                    ForEach(weekdaySymbols, id: \.self) { day in
                        Text(day)
                            .themeFont(.caption2, weight: .semibold)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(cells.indices, id: \.self) { index in
                        if let cell = cells[index] {
                            Button {
                                selectedDate = selectedDate == cell.dateKey ? nil : cell.dateKey
                            } label: {
                                Text("\(cell.day)")
                                    .themeFont(.caption, weight: cell.isToday ? .bold : .semibold)
                                    .foregroundStyle(cell.count > 0 ? Color.white : Color.secondary)
                                    .frame(maxWidth: .infinity, minHeight: 32)
                                    .background(heatBackground(cell.count), in: RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(selectedDate == cell.dateKey ? Color("BrandBlue") : .clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(cellAccessibilityLabel(cell))
                        } else {
                            Color.clear.frame(minHeight: 32)
                        }
                    }
                }

                Divider().padding(.top, 4)

                HStack {
                    Text(preferences.t("history.calendarLegend"))
                        .themeFont(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 6) {
                        legendSwatch(count: 0)
                        legendSwatch(count: 1)
                        legendSwatch(count: 2)
                        legendSwatch(count: 3)
                    }
                }
            }
        }
    }

    private var monthTitle: String {
        let components = DateComponents(year: viewYear, month: viewMonth, day: 1)
        let date = Calendar.current.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = preferences.locale
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private var sessionsByDate: [String: Int] {
        sessions.reduce(into: [:]) { result, session in
            result[session.date, default: 0] += 1
        }
    }

    private var cells: [CalendarCell?] {
        let components = DateComponents(year: viewYear, month: viewMonth, day: 1)
        guard let firstDay = Calendar.current.date(from: components),
              let range = Calendar.current.range(of: .day, in: .month, for: firstDay) else { return [] }

        let weekday = (Calendar.current.component(.weekday, from: firstDay) + 5) % 7
        var result = Array(repeating: CalendarCell?.none, count: weekday)

        for day in range {
            let dateKey = String(format: "%04d-%02d-%02d", viewYear, viewMonth, day)
            result.append(CalendarCell(day: day, dateKey: dateKey, count: sessionsByDate[dateKey] ?? 0, isToday: dateKey == todayKey))
        }
        while result.count % 7 != 0 { result.append(nil) }
        return result
    }

    private func shiftMonth(_ delta: Int) {
        let components = DateComponents(year: viewYear, month: viewMonth + delta, day: 1)
        guard let date = Calendar.current.date(from: components) else { return }
        viewYear = Calendar.current.component(.year, from: date)
        viewMonth = Calendar.current.component(.month, from: date)
    }

    private var weekdaySymbols: [String] {
        var calendar = Calendar.current
        calendar.locale = preferences.locale
        let symbols = calendar.veryShortWeekdaySymbols
        // Grid is Monday-first; rotate labels to match day columns.
        let mondayIndex = 1
        return Array(symbols[mondayIndex...] + symbols[..<mondayIndex])
    }

    private func cellAccessibilityLabel(_ cell: CalendarCell) -> String {
        if cell.count == 0 {
            return "\(cell.day)"
        }
        return "\(cell.day), \(cell.count) sessions"
    }

    private func heatBackground(_ count: Int) -> AnyShapeStyle {
        switch count {
        case 0:
            return AnyShapeStyle(Color(.systemGray5))
        case 1:
            return AnyShapeStyle(Color("BrandBlue").opacity(0.72))
        case 2:
            return AnyShapeStyle(Color("BrandBlue"))
        default:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color("BrandBlue"), Color(red: 0.48, green: 0.36, blue: 1.0)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private func legendSwatch(count: Int) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(heatBackground(count))
            .frame(width: 16, height: 16)
    }

    private var todayKey: String {
        let today = Date()
        let year = Calendar.current.component(.year, from: today)
        let month = Calendar.current.component(.month, from: today)
        let day = Calendar.current.component(.day, from: today)
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private struct CalendarCell {
        let day: Int
        let dateKey: String
        let count: Int
        let isToday: Bool
    }
}
