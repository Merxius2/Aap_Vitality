import SwiftUI
import Charts

struct ProgressScreen: View {
    @EnvironmentObject private var viewModel: SwimViewModel
    @EnvironmentObject private var preferences: UserPreferencesService
    @Environment(\.openSettingsTab) private var openSettingsTab

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(
                        preferences.t("progress.title"),
                        subtitle: preferences.t("progress.subtitle"),
                        pageKey: "progress",
                        systemImage: "chart.line.uptrend.xyaxis"
                    )

                    if viewModel.dailyRecords.isEmpty {
                        emptyState
                    } else {
                        overviewCard
                        MonthlyChallengesCardView()
                        todayVitalityCard
                        goalSnapshotCard
                        recentPointsChart
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
                    Image(systemName: "heart.text.square.fill")
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
        let displayName = name.isEmpty ? preferences.t("settings.defaultProfileName") : name
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

    private var todayVitalityCard: some View {
        let record = viewModel.todayVitalityRecord ?? viewModel.dailyRecords.max(by: { $0.date < $1.date })
        guard let record else { return AnyView(EmptyView()) }

        return AnyView(
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Text(preferences.t("vitality.todayTitle"))
                        .themeFont(.headline, weight: .semibold)
                    Text(SwimFormatters.formatDateShort(record.date))
                        .themeFont(.caption)
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        metricBlock(preferences.t("vitality.highlight.steps"), value: "\(record.steps)", color: .green)
                        metricBlock(preferences.t("vitality.highlight.points"), value: "\(record.totalPoints)", color: Color("BrandBlue"))
                        metricBlock(preferences.t("vitality.stepPoints"), value: "\(record.stepPoints)", color: .teal)
                        metricBlock(preferences.t("vitality.workoutPoints"), value: "\(record.workoutPoints)", color: .orange)
                    }
                    stepTierRow(record: record)
                }
            }
        )
    }

    private func stepTierRow(record: DailyVitalityRecord) -> some View {
        HStack(spacing: 8) {
            ForEach(VitalityPoints.stepMilestones, id: \.self) { milestone in
                let reached = record.steps >= milestone
                Text("\(milestone / 1000)k")
                    .themeFont(.caption2, weight: .semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(reached ? Color.green.opacity(0.18) : Color.secondary.opacity(0.12), in: Capsule())
                    .foregroundStyle(reached ? .green : .secondary)
            }
        }
    }

    private var goalSnapshotCard: some View {
        let snapshot = viewModel.vitalityGoalSnapshot
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                Text(preferences.t("goals.snapshotTitle"))
                    .themeFont(.headline, weight: .semibold)
                HStack {
                    goalPill(preferences.t("goals.weekly"), percent: snapshot.weeklyPercent)
                    goalPill(preferences.t("goals.monthly"), percent: snapshot.monthlyPercent)
                    goalPill(preferences.t("goals.yearly"), percent: snapshot.yearlyPercent)
                }
            }
        }
    }

    private func goalPill(_ title: String, percent: Int) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .themeFont(.caption2)
                .foregroundStyle(.secondary)
            Text("\(percent)%")
                .themeFont(.headline, weight: .bold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color("BrandBlue").opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private var recentPointsChart: some View {
        let records = viewModel.dailyRecords.suffix(14)
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                Text(preferences.t("vitality.recentPoints"))
                    .themeFont(.headline, weight: .semibold)
                Chart {
                    ForEach(Array(records), id: \.id) { record in
                        BarMark(
                            x: .value("Date", SwimFormatters.formatDateShort(record.date)),
                            y: .value("Points", record.totalPoints)
                        )
                        .foregroundStyle(Color("BrandBlue"))
                    }
                }
                .frame(height: 180)
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
}
