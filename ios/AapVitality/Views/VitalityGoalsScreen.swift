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
                    ScreenHeader(
                        preferences.t("goals.title"),
                        subtitle: preferences.t("goals.subtitle"),
                        pageKey: "goals",
                        systemImage: "target"
                    )

                    if viewModel.profile.sex.isEmpty || viewModel.profile.age <= 0 {
                        profileRequiredCard
                    } else {
                        goalCard(
                            title: preferences.t("goals.monthly"),
                            earned: snapshot.monthlyEarned,
                            target: snapshot.monthlyTarget,
                            percent: snapshot.monthlyPercent,
                            color: Color("BrandBlue")
                        )
                        goalCard(
                            title: preferences.t("goals.weekly"),
                            earned: snapshot.weeklyEarned,
                            target: snapshot.weeklyTarget,
                            percent: snapshot.weeklyPercent,
                            color: .teal
                        )
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

                        Card {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(preferences.t("goals.scoringTitle"))
                                    .themeFont(.headline, weight: .semibold)
                                Label(preferences.t("goals.scoringSteps"), systemImage: "figure.walk")
                                Label(preferences.t("goals.scoringWorkouts"), systemImage: "heart.fill")
                                Label(preferences.t("goals.scoringZones"), systemImage: "waveform.path.ecg")
                            }
                            .themeFont(.subheadline)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(preferences.t("goals.title"))
            .navigationBarTitleDisplayMode(.inline)
            .themedNavigationBar()
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
