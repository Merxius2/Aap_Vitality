import SwiftUI
import Charts

struct ProgressScreen: View {
    @EnvironmentObject private var viewModel: SwimViewModel
    @EnvironmentObject private var preferences: UserPreferencesService
    @Environment(\.openUpload) private var openUpload
    @Environment(\.openSettingsTab) private var openSettingsTab

    @State private var chartsInteractive = false
    @State private var chartScope: ProgressChartScope = .allTime
    @State private var selectedPaceDate: String?
    @State private var selectedDistanceDate: String?
    @State private var selectedCaloriesDate: String?
    @State private var selectedHeartRateDate: String?
    @State private var selectedVolumeWeek: String?

    private let paceTeal = Color(red: 0.078, green: 0.722, blue: 0.651)

    var body: some View {
        let chartPoints = scopedChartPoints
        let weeklyVolume = scopedWeeklyVolume

        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(
                        preferences.t("progress.title"),
                        subtitle: preferences.t("progress.subtitle"),
                        pageKey: "progress",
                        systemImage: "chart.line.uptrend.xyaxis"
                    )

                    if viewModel.sessions.isEmpty {
                        emptyState
                    } else {
                        overviewCard
                        MonthlyChallengesCardView()
                        latestSessionCard
                        allTimeStatsCard
                        RecordsSectionView(records: viewModel.progressPersonalRecords)
                        if let feedback = viewModel.latestSessionProgressFeedback(t: preferences.translations) {
                            SessionFeedbackCard(
                                feedback: feedback,
                                titleKey: "progress.sessionFeedbackTitle"
                            )
                        }
                        chartsSectionHeader
                        chartScopePicker
                        paceChart(points: chartPoints)
                        distanceChart(points: chartPoints)
                        caloriesChart(points: chartPoints)
                        heartRateChart(points: chartPoints)
                        volumeChart(weekly: weeklyVolume)
                        strokeMixChart
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .navigationTitle(preferences.t("progress.title"))
            .navigationBarTitleDisplayMode(.inline)
            .themedNavigationBar()
            .themedPageBackground()
        }
        .onChange(of: chartScope) { _, _ in
            clearChartSelections()
        }
    }

    private var scopedSessions: [SwimSession] {
        SwimAnalysis.filterSessions(viewModel.sessions, scope: chartScope)
    }

    private var scopedChartPoints: [ChartSessionPoint] {
        ChartMovingAverage.enrichChartSessions(SwimAnalysis.chartSessions(scopedSessions))
    }

    private var scopedWeeklyVolume: [WeeklyVolumePoint] {
        ChartMovingAverage.enrichWeeklyVolume(SwimAnalysis.weeklyVolumeData(scopedSessions))
    }

    private func clearChartSelections() {
        selectedPaceDate = nil
        selectedDistanceDate = nil
        selectedCaloriesDate = nil
        selectedHeartRateDate = nil
        selectedVolumeWeek = nil
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Card {
                MascotCoachView(
                    mascotId: viewModel.mascotId,
                    message: emptyMascotMessage,
                    level: MascotConstants.coachedLevel(viewModel.mascotId),
                    coachName: MascotConstants.displayName(viewModel.mascotId, t: preferences.translations),
                    size: 200,
                    animated: true,
                    layout: .stacked
                )
                .frame(maxWidth: .infinity)
            }

            Card {
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 44))
                        .foregroundStyle(Color("BrandBlue"))
                    Text(preferences.t("progress.emptyTitle"))
                        .themeFont(.title2, weight: .bold)
                    Text(preferences.t("progress.emptyDesc"))
                        .themeFont(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button(action: openSettingsTab) {
                        Text(preferences.t("progress.emptyCta"))
                            .themeFont(.subheadline, weight: .semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("BrandBlue"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
    }

    private var emptyMascotMessage: String {
        let template = preferences.t("progress.mascotEmpty")
        let name = viewModel.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = name.isEmpty ? preferences.t("settings.swimmerNamePlaceholder") : name
        return template.replacingOccurrences(of: "{name}", with: displayName)
    }

    private var overviewCard: some View {
        let overviewMessage = viewModel.progressOverviewMessage(t: preferences.translations)
        let overviewTone = MascotPresentation.resolveBubbleTone(message: overviewMessage)

        return Card {
            VStack(alignment: .leading, spacing: 12) {
                Text(preferences.t("progress.overviewTitle"))
                    .themeFont(.caption, weight: .bold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(1.1)

                MascotCoachView(
                    mascotId: viewModel.mascotId,
                    message: overviewMessage,
                    level: MascotConstants.coachedLevel(viewModel.mascotId),
                    bubbleTone: overviewTone,
                    coachName: MascotConstants.displayName(viewModel.mascotId, t: preferences.translations),
                    size: 220,
                    animated: true,
                    layout: .stacked
                )
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var latestSessionCard: some View {
        let latest = viewModel.sessions.last!
        let m = latest.metrics
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                Text(preferences.t("progress.latestSession"))
                    .themeFont(.headline, weight: .semibold)
                Text(SwimFormatters.formatDateShort(latest.date))
                    .themeFont(.caption)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    metricBlock(preferences.t("upload.fields.distance"), value: SwimFormatters.formatDistance(m.distanceM), color: .blue)
                    metricBlock(preferences.t("upload.fields.duration"), value: SwimFormatters.formatDuration(m.durationSec), color: .orange)
                    metricBlock(preferences.t("upload.fields.pace"), value: SwimFormatters.formatPace(m.paceSecPer100m), color: .teal)
                    metricBlock(preferences.t("upload.fields.heartRate"), value: m.avgHeartRate.map { "\($0) " + preferences.t("common.bpm") } ?? "—", color: .pink)
                }
            }
        }
    }

    private var allTimeStatsCard: some View {
        guard let combined = viewModel.progressCombinedStats else {
            return AnyView(EmptyView())
        }
        let excluded = viewModel.sessions.count - viewModel.progressStatsSessionCount
        return AnyView(
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Text(preferences.t("progress.allTimeStats"))
                        .themeFont(.headline, weight: .semibold)
                    if excluded > 0 {
                        Text(preferences.t("progress.statsBasedOn", params: [
                            "count": String(combined.sessionCount),
                            "total": String(viewModel.sessions.count)
                        ]))
                            .themeFont(.caption)
                            .foregroundStyle(.secondary)
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        statTile(preferences.t("progress.totalSessions"), value: "\(combined.sessionCount)")
                        statTile(preferences.t("progress.totalDistance"), value: SwimFormatters.formatDistance(combined.totalDistanceM))
                        statTile(preferences.t("progress.totalTime"), value: SwimFormatters.formatDuration(combined.totalDurationSec))
                        statTile(preferences.t("progress.avgPace"), value: SwimFormatters.formatPace(combined.avgPaceSecPer100m))
                        statTile(preferences.t("progress.bestPace"), value: SwimFormatters.formatPace(combined.bestPaceSecPer100m))
                        statTile(preferences.t("progress.totalCalories"), value: "\(combined.totalActiveKcal) " + preferences.t("common.kcal"))
                        statTile(preferences.t("progress.totalLaps"), value: "\(combined.totalLaps)")
                        statTile(preferences.t("progress.avgHeartRate"), value: combined.avgHeartRate.map { "\($0) " + preferences.t("common.bpm") } ?? "—")
                    }
                }
            }
        )
    }

    @ViewBuilder
    private var strokeMixChart: some View {
        let slices = SwimAnalysis.strokeChartData(scopedSessions, t: preferences.translations)
        if !slices.isEmpty {
            StrokeDonutChart(slices: slices)
        }
    }

    private var chartScopePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ProgressChartScope.allCases) { scope in
                    Button {
                        chartScope = scope
                    } label: {
                        Text(preferences.t(scope.nameKey))
                            .themeFont(.caption, weight: chartScope == scope ? .semibold : .regular)
                            .foregroundStyle(chartScope == scope ? Color("BrandBlue") : .secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background {
                                Capsule()
                                    .fill(chartScope == scope
                                        ? Color("BrandBlue").opacity(0.14)
                                        : Color.secondary.opacity(0.12))
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var chartsSectionHeader: some View {
        HStack {
            Text(preferences.t("progress.chartsSection"))
                .themeFont(.caption, weight: .bold)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                chartsInteractive.toggle()
            } label: {
                Label(
                    chartsInteractive
                        ? preferences.t("progress.chartsInteractiveOn")
                        : preferences.t("progress.chartsInteractiveOff"),
                    systemImage: "hand.tap"
                )
                .themeFont(.caption, weight: .semibold)
            }
            .buttonStyle(.bordered)
            .tint(chartsInteractive ? Color("BrandBlue") : .secondary)
        }
        .padding(.horizontal, 4)
    }

    private let movingAverageColor = Color(red: 0.388, green: 0.400, blue: 0.945)

    private func paceChart(points: [ChartSessionPoint]) -> some View {
        let filteredPoints = points.filter { ($0.paceSecPer100m ?? 0) > 0 }
        let domain = SwimFormatters.getPaceChartDomain(filteredPoints.map(\.paceSecPer100m))
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                Text(preferences.t("progress.paceChart"))
                    .themeFont(.headline, weight: .semibold)
                if filteredPoints.isEmpty {
                    Text(preferences.t("medals.progress.noPaceYet")).foregroundStyle(.secondary)
                } else {
                    Chart {
                        ForEach(filteredPoints) { point in
                            let invertedPace = Self.invertedPaceValue(point.paceSecPer100m)
                            LineMark(
                                x: .value("Date", point.dateLabel),
                                y: .value("Pace", invertedPace)
                            )
                            .foregroundStyle(paceTeal)
                            .interpolationMethod(.monotone)

                            PointMark(
                                x: .value("Date", point.dateLabel),
                                y: .value("Pace", invertedPace)
                            )
                            .foregroundStyle(paceTeal)
                            .symbolSize(selectedPaceDate == point.dateLabel ? 80 : 36)

                            if let paceMa = point.paceMa, paceMa > 0 {
                                LineMark(
                                    x: .value("Date", point.dateLabel),
                                    y: .value("Average", Self.invertedPaceValue(paceMa))
                                )
                                .foregroundStyle(movingAverageColor)
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                                .interpolationMethod(.monotone)
                            }

                            if chartsInteractive, selectedPaceDate == point.dateLabel {
                                RuleMark(x: .value("Date", point.dateLabel))
                                    .foregroundStyle(Color.secondary.opacity(0.35))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            }
                        }
                    }
                    .chartXAxis { sessionDateAxisMarks(count: filteredPoints.count) }
                    .chartYScale(domain: invertedPaceDomain(domain))
                    .chartYAxis { paceYAxisMarks() }
                    .chartXLabelSelection($selectedPaceDate, enabled: chartsInteractive)
                    .allowsHitTesting(chartsInteractive)
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)

                    if chartsInteractive,
                       let selectedPaceDate,
                       let point = filteredPoints.first(where: { $0.dateLabel == selectedPaceDate }) {
                        ChartSelectionFooter(
                            title: point.dateLabel,
                            value: SwimFormatters.formatPace(point.paceSecPer100m)
                        )
                    }
                }
            }
        }
    }

    private func distanceChart(points: [ChartSessionPoint]) -> some View {
        let filteredPoints = points.filter { ($0.distanceM ?? 0) > 0 }
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                Text(preferences.t("progress.distanceChart"))
                    .themeFont(.headline, weight: .semibold)
                Chart {
                    ForEach(filteredPoints) { point in
                        BarMark(
                            x: .value("Date", point.dateLabel),
                            y: .value("Distance", point.distanceM ?? 0)
                        )
                        .foregroundStyle(Color.blue.gradient)
                        .cornerRadius(4)

                        if let distanceMa = point.distanceMa {
                            LineMark(
                                x: .value("Date", point.dateLabel),
                                y: .value("Average", distanceMa)
                            )
                            .foregroundStyle(movingAverageColor)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                            .interpolationMethod(.monotone)
                        }

                        if chartsInteractive, selectedDistanceDate == point.dateLabel {
                            RuleMark(x: .value("Date", point.dateLabel))
                                .foregroundStyle(Color.secondary.opacity(0.35))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        }
                    }
                }
                .chartXAxis { sessionDateAxisMarks(count: filteredPoints.count) }
                .chartYAxis { valueAxisMarks(formatter: SwimFormatters.formatDistance) }
                .chartXLabelSelection($selectedDistanceDate, enabled: chartsInteractive)
                .allowsHitTesting(chartsInteractive)
                .frame(maxWidth: .infinity)
                .frame(height: 240)

                if chartsInteractive,
                   let selectedDistanceDate,
                   let point = filteredPoints.first(where: { $0.dateLabel == selectedDistanceDate }) {
                    ChartSelectionFooter(
                        title: point.dateLabel,
                        value: SwimFormatters.formatDistance(point.distanceM)
                    )
                }
            }
        }
    }

    private func caloriesChart(points: [ChartSessionPoint]) -> some View {
        let activeLabel = preferences.t("progress.activeKcal")
        let totalLabel = preferences.t("progress.totalKcal")
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                Text(preferences.t("progress.caloriesChart"))
                    .themeFont(.headline, weight: .semibold)
                Chart {
                    ForEach(points) { point in
                        AreaMark(
                            x: .value("Date", point.dateLabel),
                            y: .value("Calories", point.activeKcal ?? 0),
                            series: .value("Series", activeLabel)
                        )
                        .foregroundStyle(Color.red.opacity(0.3))
                        .interpolationMethod(.monotone)

                        AreaMark(
                            x: .value("Date", point.dateLabel),
                            y: .value("Calories", point.totalKcal ?? 0),
                            series: .value("Series", totalLabel)
                        )
                        .foregroundStyle(Color.orange.opacity(0.2))
                        .interpolationMethod(.monotone)

                        LineMark(
                            x: .value("Date", point.dateLabel),
                            y: .value("Calories", point.activeKcal ?? 0),
                            series: .value("Series", activeLabel)
                        )
                        .foregroundStyle(.red)
                        .interpolationMethod(.monotone)

                        LineMark(
                            x: .value("Date", point.dateLabel),
                            y: .value("Calories", point.totalKcal ?? 0),
                            series: .value("Series", totalLabel)
                        )
                        .foregroundStyle(.orange)
                        .interpolationMethod(.monotone)

                        if let activeKcalMa = point.activeKcalMa {
                            LineMark(
                                x: .value("Date", point.dateLabel),
                                y: .value("Average", activeKcalMa)
                            )
                            .foregroundStyle(movingAverageColor)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                            .interpolationMethod(.monotone)
                        }

                        if chartsInteractive, selectedCaloriesDate == point.dateLabel {
                            RuleMark(x: .value("Date", point.dateLabel))
                                .foregroundStyle(Color.secondary.opacity(0.35))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        }
                    }
                }
                .chartXAxis { sessionDateAxisMarks(count: points.count) }
                .chartYAxis { valueAxisMarks(formatter: { $0.map { "\($0)" } ?? "—" }) }
                .chartForegroundStyleScale([
                    activeLabel: Color.red,
                    totalLabel: Color.orange,
                ])
                .chartLegend(position: .bottom, alignment: .leading)
                .chartXLabelSelection($selectedCaloriesDate, enabled: chartsInteractive)
                .allowsHitTesting(chartsInteractive)
                .frame(maxWidth: .infinity)
                .frame(height: 240)

                if chartsInteractive,
                   let selectedCaloriesDate,
                   let point = points.first(where: { $0.dateLabel == selectedCaloriesDate }) {
                    ChartSelectionFooter(
                        title: point.dateLabel,
                        value: "\(activeLabel): \((point.activeKcal ?? 0).formatted())",
                        secondaryValue: "\(totalLabel): \((point.totalKcal ?? 0).formatted())"
                    )
                }
            }
        }
    }

    private func heartRateChart(points: [ChartSessionPoint]) -> some View {
        let filteredPoints = points.filter { ($0.avgHeartRate ?? 0) > 0 }
        let bpm = preferences.t("common.bpm")
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                Text(preferences.t("progress.heartRateChart"))
                    .themeFont(.headline, weight: .semibold)
                Chart {
                    ForEach(filteredPoints) { point in
                        LineMark(
                            x: .value("Date", point.dateLabel),
                            y: .value("BPM", point.avgHeartRate ?? 0)
                        )
                        .foregroundStyle(.orange)
                        .interpolationMethod(.monotone)

                        PointMark(
                            x: .value("Date", point.dateLabel),
                            y: .value("BPM", point.avgHeartRate ?? 0)
                        )
                        .foregroundStyle(.orange)
                        .symbolSize(selectedHeartRateDate == point.dateLabel ? 70 : 30)

                        if let avgHeartRateMa = point.avgHeartRateMa {
                            LineMark(
                                x: .value("Date", point.dateLabel),
                                y: .value("Average", avgHeartRateMa)
                            )
                            .foregroundStyle(movingAverageColor)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                            .interpolationMethod(.monotone)
                        }

                        if chartsInteractive, selectedHeartRateDate == point.dateLabel {
                            RuleMark(x: .value("Date", point.dateLabel))
                                .foregroundStyle(Color.secondary.opacity(0.35))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        }
                    }
                }
                .chartXAxis { sessionDateAxisMarks(count: filteredPoints.count) }
                .chartYAxis { valueAxisMarks(formatter: { $0.map { "\($0)" } ?? "—" }) }
                .chartXLabelSelection($selectedHeartRateDate, enabled: chartsInteractive)
                .allowsHitTesting(chartsInteractive)
                .frame(maxWidth: .infinity)
                .frame(height: 240)

                if chartsInteractive,
                   let selectedHeartRateDate,
                   let point = filteredPoints.first(where: { $0.dateLabel == selectedHeartRateDate }) {
                    ChartSelectionFooter(
                        title: point.dateLabel,
                        value: "\(point.avgHeartRate ?? 0) \(bpm)"
                    )
                }
            }
        }
    }

    private func volumeChart(weekly: [WeeklyVolumePoint]) -> some View {
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                Text(preferences.t("progress.weeklyVolume"))
                    .themeFont(.headline, weight: .semibold)
                if weekly.isEmpty {
                    Text(preferences.t("progress.emptyDesc")).foregroundStyle(.secondary)
                } else {
                    Chart {
                        ForEach(weekly) { week in
                            BarMark(
                                x: .value("Week", week.weekLabel),
                                y: .value("Distance", week.distanceM)
                            )
                            .foregroundStyle(Color.purple.gradient)
                            .cornerRadius(4)

                            if let distanceMa = week.distanceMa {
                                LineMark(
                                    x: .value("Week", week.weekLabel),
                                    y: .value("Average", distanceMa)
                                )
                                .foregroundStyle(movingAverageColor)
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                                .interpolationMethod(.monotone)
                            }

                            if chartsInteractive, selectedVolumeWeek == week.weekLabel {
                                RuleMark(x: .value("Week", week.weekLabel))
                                    .foregroundStyle(Color.secondary.opacity(0.35))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            }
                        }
                    }
                    .chartXAxis { sessionDateAxisMarks(count: weekly.count) }
                    .chartYAxis { valueAxisMarks(formatter: SwimFormatters.formatDistance) }
                    .chartXLabelSelection($selectedVolumeWeek, enabled: chartsInteractive)
                    .allowsHitTesting(chartsInteractive)
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)

                    if chartsInteractive,
                       let selectedVolumeWeek,
                       let week = weekly.first(where: { $0.weekLabel == selectedVolumeWeek }) {
                        ChartSelectionFooter(
                            title: week.weekLabel,
                            value: SwimFormatters.formatDistance(week.distanceM)
                        )
                    }
                }
            }
        }
    }

    private static func invertedPaceValue(_ paceSecPer100m: Int?) -> Double {
        guard let paceSecPer100m, paceSecPer100m > 0 else { return 0 }
        return Double(-paceSecPer100m)
    }

    private func invertedPaceDomain(_ domain: ClosedRange<Double>?) -> ClosedRange<Double> {
        let range = domain ?? 90...180
        return (-range.upperBound)...(-range.lowerBound)
    }

    private func sessionDateAxisMarks(count: Int) -> some AxisContent {
        AxisMarks(values: .automatic(desiredCount: min(5, max(count, 1)))) { _ in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundStyle(Color.secondary.opacity(0.25))
            AxisValueLabel()
        }
    }

    private func paceYAxisMarks() -> some AxisContent {
        AxisMarks { value in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundStyle(Color.secondary.opacity(0.25))
            AxisTick()
            AxisValueLabel {
                if let invertedSeconds = value.as(Double.self) {
                    Text(SwimFormatters.formatPaceChartLabel(Int((-invertedSeconds).rounded())))
                }
            }
        }
    }

    private func valueAxisMarks(formatter: @escaping (Int?) -> String) -> some AxisContent {
        AxisMarks { value in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundStyle(Color.secondary.opacity(0.25))
            AxisTick()
            AxisValueLabel {
                if let number = value.as(Int.self) {
                    Text(formatter(number))
                }
            }
        }
    }

    private func metricBlock(_ title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .themeFont(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .themeFont(.subheadline, weight: .bold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statTile(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .themeFont(.caption2, weight: .semibold)
                .foregroundStyle(.secondary)
            Text(value)
                .themeFont(.subheadline, weight: .bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
