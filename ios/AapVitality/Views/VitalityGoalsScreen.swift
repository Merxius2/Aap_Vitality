import SwiftUI

struct VitalityGoalsScreen: View {
    @EnvironmentObject private var viewModel: VitalityViewModel
    @EnvironmentObject private var preferences: UserPreferencesService
    @Environment(\.openSettingsTab) private var openSettingsTab

    var body: some View {
        let snapshot = viewModel.vitalityGoalSnapshot

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.profile.sex.isEmpty || viewModel.profile.age <= 0 {
                        profileRequiredCard
                    } else {
                        goalCard(
                            title: preferences.t("goals.weekly"),
                            earned: snapshot.weeklyEarned,
                            target: snapshot.weeklyTarget,
                            percent: snapshot.weeklyPercent,
                            color: .teal
                        )
                        monthlyGoalCard(snapshot: snapshot)
                        goalCard(
                            title: preferences.t("goals.yearly"),
                            earned: snapshot.yearlyEarned,
                            target: snapshot.yearlyTarget,
                            percent: snapshot.yearlyPercent,
                            color: .orange
                        )

                        Card {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(preferences.t("goals.howItWorksTitle"))
                                    .themeFont(.headline, weight: .semibold)
                                Text(preferences.t("goals.howItWorksDesc"))
                                    .themeFont(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(preferences.t("goals.earlyFinishNote"))
                                    .themeFont(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        VitalityScoringGuideView()
                    }
                }
                .padding()
            }
            .tabBarScrollInset()
            .toolbar(.hidden, for: .navigationBar)
            .themedPageBackground()
        }
    }

    private var profileRequiredCard: some View {
        Card {
            VStack(spacing: 12) {
                Text(preferences.t("goals.profileRequired"))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button(action: openSettingsTab) {
                    Text(preferences.t("benchmark.goSettings"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("BrandBlue"))
            }
        }
    }

    private func monthlyGoalCard(snapshot: VitalityGoalSnapshot) -> some View {
        let color = Color("BrandBlue")
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(preferences.t("goals.monthly"))
                        .themeFont(.headline, weight: .semibold)
                    Spacer()
                    Text("\(snapshot.monthlyPercent)%")
                        .themeFont(.title3, weight: .bold)
                        .foregroundStyle(color)
                }
                ProgressView(
                    value: Double(min(snapshot.monthlyEarned, snapshot.monthlyTarget)),
                    total: Double(max(snapshot.monthlyTarget, 1))
                )
                .tint(color)
                Text(preferences.t("goals.progressLine", params: [
                    "current": String(snapshot.monthlyEarned),
                    "target": String(snapshot.monthlyTarget)
                ]))
                .themeFont(.caption)
                .foregroundStyle(.secondary)

                EarlyFinishBonusView(
                    earlyFinish: snapshot.earlyFinish,
                    label: { preferences.t($0, params: $1) }
                )
            }
        }
    }

    private func goalCard(title: String, earned: Int, target: Int, percent: Int, color: Color) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title)
                        .themeFont(.headline, weight: .semibold)
                    Spacer()
                    Text("\(percent)%")
                        .themeFont(.title3, weight: .bold)
                        .foregroundStyle(color)
                }
                ProgressView(value: Double(min(earned, target)), total: Double(max(target, 1)))
                    .tint(color)
                Text(preferences.t("goals.progressLine", params: [
                    "current": String(earned),
                    "target": String(target)
                ]))
                .themeFont(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}

private struct EarlyFinishBonusView: View {
    let earlyFinish: EarlyFinishSnapshot
    let label: (String, [String: String]) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            HStack(spacing: 6) {
                Image(systemName: headerIcon)
                    .foregroundStyle(headerColor)
                Text(label("goals.earlyFinishTitle", [:]))
                    .themeFont(.caption, weight: .bold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            Text(
                label("goals.earlyFinishSubtitle", [
                    "day": String(earlyFinish.deadlineDay),
                    "boost": String(earlyFinish.boostPercent)
                ])
            )
            .themeFont(.caption)
            .foregroundStyle(.secondary)

            switch earlyFinish.status {
            case .secured(let completedOnDay):
                securedBanner(completedOnDay: completedOnDay)
            case .inWindow:
                dualProgressBars
                statusLine
            case .missedWindow:
                missedBanner
            case .completedLate(let completedOnDay):
                lateBanner(completedOnDay: completedOnDay)
            }
        }
        .padding(.top, 4)
    }

    private var dualProgressBars: some View {
        VStack(alignment: .leading, spacing: 8) {
            progressRow(
                title: label("goals.earlyFinishDaysLabel", [:]),
                detail: label("goals.earlyFinishDays", [
                    "current": String(earlyFinish.currentDayOfMonth),
                    "deadline": String(earlyFinish.deadlineDay)
                ]),
                progress: earlyFinish.timeProgress,
                color: .orange
            )
            progressRow(
                title: label("goals.earlyFinishPointsLabel", [:]),
                detail: label("goals.progressLine", [
                    "current": String(earlyFinish.monthlyEarned),
                    "target": String(earlyFinish.monthlyTarget)
                ]),
                progress: earlyFinish.pointsProgress,
                color: Color("BrandBlue")
            )
        }
    }

    private func progressRow(title: String, detail: String, progress: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .themeFont(.caption2, weight: .semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(detail)
                    .themeFont(.caption2)
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(color.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(color)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 8)
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        if case .inWindow(_, let onTrack) = earlyFinish.status {
            HStack(spacing: 6) {
                Circle()
                    .fill(onTrack ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                if onTrack {
                    Text(label("goals.earlyFinishOnTrack", [:]))
                        .themeFont(.caption2, weight: .semibold)
                        .foregroundStyle(.green)
                } else if case .inWindow(let daysRemaining, _) = earlyFinish.status {
                    let pointsNeeded = max(0, earlyFinish.monthlyTarget - earlyFinish.monthlyEarned)
                    Text(label("goals.earlyFinishBehind", [
                        "points": String(pointsNeeded),
                        "days": String(daysRemaining)
                    ]))
                    .themeFont(.caption2, weight: .semibold)
                    .foregroundStyle(.orange)
                }
            }
        }
    }

    private func securedBanner(completedOnDay: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
            Text(label("goals.earlyFinishSecured", [
                "day": String(completedOnDay),
                "boost": String(earlyFinish.boostPercent)
            ]))
            .themeFont(.caption, weight: .semibold)
            .foregroundStyle(.green)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    private var missedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.badge.xmark")
                .foregroundStyle(.secondary)
            Text(label("goals.earlyFinishMissed", [:]))
                .themeFont(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private func lateBanner(completedOnDay: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "flag.checkered")
                .foregroundStyle(.secondary)
            Text(label("goals.earlyFinishLate", [
                "day": String(completedOnDay)
            ]))
            .themeFont(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private var headerIcon: String {
        switch earlyFinish.status {
        case .secured: return "bolt.circle.fill"
        case .inWindow: return "bolt.fill"
        case .missedWindow: return "clock"
        case .completedLate: return "flag.checkered"
        }
    }

    private var headerColor: Color {
        switch earlyFinish.status {
        case .secured: return .green
        case .inWindow(_, let onTrack): return onTrack ? .orange : .orange
        case .missedWindow, .completedLate: return .secondary
        }
    }
}
