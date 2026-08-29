import SwiftUI
import Charts

struct BodyProgressTrendCard: View {
    @EnvironmentObject private var viewModel: VitalityViewModel
    @EnvironmentObject private var preferences: UserPreferencesService

    var body: some View {
        let snapshot = viewModel.bodyProgressSnapshot
        Card {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(preferences.t("progress.body.title"))
                        .themeFont(.headline, weight: .semibold)
                    Text(preferences.t("progress.body.subtitle"))
                        .themeFont(.caption)
                        .foregroundStyle(.secondary)
                }

                if snapshot.latestWeightKg == nil {
                    emptyState
                } else {
                    summaryRow(snapshot: snapshot)
                    if !snapshot.weeklyTrend.isEmpty {
                        trendChart(snapshot: snapshot)
                    }
                    disclaimer
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(preferences.t("progress.body.empty"))
                .themeFont(.subheadline)
                .foregroundStyle(.secondary)
            Text(preferences.t("progress.body.emptyHint"))
                .themeFont(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func summaryRow(snapshot: BodyProgressSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                metricBlock(
                    title: preferences.t("progress.body.weight"),
                    value: snapshot.latestWeightKg.map {
                        BodyProgress.formatWeight($0, t: preferences.translations)
                    } ?? "—"
                )
                if let bmi = snapshot.latestBMI {
                    metricBlock(
                        title: preferences.t("progress.body.bmi"),
                        value: BodyProgress.formatBMI(bmi)
                    )
                }
            }
            HStack(alignment: .top, spacing: 12) {
                if let bodyFat = snapshot.latestBodyFatPercent {
                    metricBlock(
                        title: preferences.t("progress.body.bodyFat"),
                        value: "\(String(format: "%.1f", bodyFat))%"
                    )
                }
                if let muscle = snapshot.latestMusclePercent {
                    metricBlock(
                        title: preferences.t("progress.body.muscle"),
                        value: "\(String(format: "%.1f", muscle))%"
                    )
                }
            }
        }
    }

    private func metricBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .themeFont(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .themeFont(.subheadline, weight: .bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color("BrandBlue").opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private func trendChart(snapshot: BodyProgressSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(preferences.t("progress.body.trendTitle"))
                .themeFont(.caption, weight: .bold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Chart {
                ForEach(snapshot.weeklyTrend) { point in
                    LineMark(
                        x: .value("Week", point.label),
                        y: .value("Weight", point.averageWeightKg)
                    )
                    .foregroundStyle(Color("BrandBlue"))
                    PointMark(
                        x: .value("Week", point.label),
                        y: .value("Weight", point.averageWeightKg)
                    )
                    .foregroundStyle(Color("BrandBlue"))
                }
            }
            .chartYAxisLabel(preferences.t("progress.body.weightAxis"))
            .frame(height: 160)

            if let change = snapshot.weightChange8WeeksKg {
                let directionKey = change <= 0 ? "progress.body.trendDown" : "progress.body.trendUp"
                Text(preferences.t(directionKey, params: [
                    "change": BodyProgress.formatWeight(abs(change), t: preferences.translations)
                ]))
                .themeFont(.caption)
                .foregroundStyle(change <= 0 ? .green : .secondary)
            }
            if let change = snapshot.muscleChange8WeeksPercent {
                Text(preferences.t("progress.body.muscleTrendUp", params: [
                    "change": String(format: "%.1f", change)
                ]))
                .themeFont(.caption)
                .foregroundStyle(change >= BodyProgress.muscleTrendTargetPercent ? .green : .secondary)
            }
        }
    }

    private var disclaimer: some View {
        Text(preferences.t("progress.body.disclaimer"))
            .themeFont(.caption2)
            .foregroundStyle(.secondary)
    }
}

struct BodyProgressChallengesCard: View {
    @EnvironmentObject private var viewModel: VitalityViewModel
    @EnvironmentObject private var preferences: UserPreferencesService

    private let tierSteps = ["bronze", "silver", "gold"]

    var body: some View {
        let state = viewModel.currentBodyProgressChallenges
        let currentTierIndex = state.tier.flatMap { tierSteps.firstIndex(of: $0) } ?? -1

        Card {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(preferences.t("progress.body.challengesTitle"))
                        .themeFont(.headline, weight: .semibold)
                    Text(preferences.t("progress.body.challengesSubtitle"))
                        .themeFont(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(state.challenges) { challenge in
                    challengeRow(challenge: challenge)
                }

                HStack(spacing: 6) {
                    ForEach(Array(tierSteps.enumerated()), id: \.offset) { index, tier in
                        Circle()
                            .fill(index <= currentTierIndex ? tierColor(tier) : Color(.systemGray4))
                            .frame(width: 8, height: 8)
                    }
                    if let tier = state.tier {
                        Text(SwimMonthlyChallengeFormatters.tierLabel(tier, t: preferences.translations))
                            .themeFont(.caption2, weight: .semibold)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func challengeRow(challenge: MonthlyChallenge) -> some View {
        let pct = challenge.target > 0
            ? min(100, Int(round(Double(challenge.current) / Double(challenge.target) * 100)))
            : 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(SwimMonthlyChallengeFormatters.challengeTypeLabel(challenge.type, t: preferences.translations))
                    .themeFont(.subheadline, weight: .semibold)
                Spacer()
                if challenge.completed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            Text(SwimMonthlyChallengeFormatters.formatChallengeTarget(challenge.type, challenge.target, t: preferences.translations))
                .themeFont(.caption)
                .foregroundStyle(.secondary)
            ProgressView(value: Double(pct), total: 100)
                .tint(challenge.completed ? .green : Color("BrandBlue"))
            Text(SwimMonthlyChallengeFormatters.formatChallengeValue(challenge.type, challenge.current, t: preferences.translations))
                .themeFont(.caption2)
                .foregroundStyle(.secondary)
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
