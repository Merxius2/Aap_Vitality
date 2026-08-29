import SwiftUI

struct VitalityScoringGuideView: View {
    @EnvironmentObject private var preferences: UserPreferencesService

    private var maxStepPoints: Int {
        VitalityPoints.stepMilestonePoints.reduce(0, +)
    }

    private var maxSleepPoints: Int {
        VitalityPoints.sleepMilestonePoints.reduce(0, +)
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(preferences.t("goals.scoringTitle"))
                        .themeFont(.headline, weight: .semibold)
                    Text(preferences.t("goals.scoringIntro"))
                        .themeFont(.caption)
                        .foregroundStyle(.secondary)
                }

                scoringSection(
                    title: preferences.t("goals.scoringStepsTitle"),
                    systemImage: "figure.walk",
                    tint: .green
                ) {
                    tierGrid(
                        items: zip(VitalityPoints.stepMilestones, VitalityPoints.stepMilestonePoints).map { milestone, points in
                            (
                                label: stepLabel(milestone),
                                points: points
                            )
                        },
                        tint: .green
                    )
                    sectionFooter(preferences.t("goals.scoringStepsMax", params: ["points": String(maxStepPoints)]))
                }

                scoringSection(
                    title: preferences.t("goals.scoringSleepTitle"),
                    systemImage: "moon.zzz.fill",
                    tint: .purple
                ) {
                    tierGrid(
                        items: zip(VitalityPoints.sleepMilestonesMinutes, VitalityPoints.sleepMilestonePoints).map { minutes, points in
                            (
                                label: sleepLabel(minutes),
                                points: points
                            )
                        },
                        tint: .purple
                    )
                    sectionFooter(preferences.t("goals.scoringSleepMax", params: ["points": String(maxSleepPoints)]))
                }

                scoringSection(
                    title: preferences.t("goals.scoringWorkoutTitle"),
                    systemImage: "heart.fill",
                    tint: .orange
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        ruleRow(
                            icon: "clock.fill",
                            text: preferences.t(
                                "goals.scoringWorkoutMin",
                                params: ["minutes": String(VitalityPoints.minWorkoutMinutes)]
                            )
                        )
                        ruleRow(
                            icon: "star.fill",
                            text: preferences.t(
                                "goals.scoringWorkoutBase",
                                params: ["points": String(VitalityPoints.baseWorkoutPoints)]
                            )
                        )
                        ruleRow(
                            icon: "plus.circle.fill",
                            text: preferences.t(
                                "goals.scoringWorkoutExtra",
                                params: [
                                    "points": String(VitalityPoints.pointsPerFiveExtraMinutes),
                                    "minutes": "5",
                                ]
                            )
                        )
                    }
                    sectionFooter(preferences.t("goals.scoringWorkoutCoachNote"))
                }

                scoringSection(
                    title: preferences.t("goals.scoringZonesTitle"),
                    systemImage: "waveform.path.ecg",
                    tint: Color("BrandBlue")
                ) {
                    Text(preferences.t("goals.scoringZonesSubtitle"))
                        .themeFont(.caption)
                        .foregroundStyle(.secondary)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5),
                        spacing: 8
                    ) {
                        ForEach(Array(VitalityPoints.zoneBonusPerMinute.enumerated()), id: \.offset) { index, bonus in
                            zoneChip(zone: index + 1, points: bonus)
                        }
                    }

                    sectionFooter(preferences.t("goals.scoringZonesProfileNote"))
                }
            }
        }
    }

    @ViewBuilder
    private func scoringSection<Content: View>(
        title: String,
        systemImage: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(title)
                    .themeFont(.subheadline, weight: .semibold)
            }

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func tierGrid(items: [(label: String, points: Int)], tint: Color) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(spacing: 4) {
                    Text(item.label)
                        .themeFont(.caption, weight: .bold)
                        .foregroundStyle(tint)
                    Text("+\(item.points)")
                        .themeFont(.caption2, weight: .semibold)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(tint.opacity(0.22), lineWidth: 1)
                )
            }
        }
    }

    private func zoneChip(zone: Int, points: Int) -> some View {
        VStack(spacing: 3) {
            Text(preferences.t("goals.scoringZoneLabel", params: ["zone": String(zone)]))
                .themeFont(.caption2, weight: .bold)
                .foregroundStyle(Color("BrandBlue"))
            Text("+\(points)")
                .themeFont(.caption2, weight: .semibold)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color("BrandBlue").opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func ruleRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 18, alignment: .center)
                .padding(.top, 2)
            Text(text)
                .themeFont(.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionFooter(_ text: String) -> some View {
        Text(text)
            .themeFont(.caption2)
            .foregroundStyle(.tertiary)
    }

    private func stepLabel(_ steps: Int) -> String {
        preferences.t("goals.scoringStepTier", params: [
            "steps": String(steps / 1000),
        ])
    }

    private func sleepLabel(_ minutes: Int) -> String {
        preferences.t("goals.scoringSleepTier", params: [
            "hours": String(minutes / 60),
        ])
    }
}
