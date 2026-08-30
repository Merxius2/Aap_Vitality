import SwiftUI
import Charts

struct ProgressScreen: View {
    @EnvironmentObject private var viewModel: VitalityViewModel
    @EnvironmentObject private var preferences: UserPreferencesService
    @Environment(\.openSettingsTab) private var openSettingsTab

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.dailyRecords.isEmpty {
                        emptyState
                    } else {
                        dailyPointsHeaderCard
                        if viewModel.profile.bodyProgressEnabled {
                            BodyProgressTrendCard()
                            BodyProgressChallengesCard()
                        }
                        overviewCard
                        levelAndStreakCard
                        workoutBadgesCard
                        recentPointsChart
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .refreshable {
                await viewModel.refreshTodayVitality()
            }
            .tabBarScrollInset()
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .toolbar(.hidden, for: .navigationBar)
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
        preferences.t(
            "progress.mascotEmpty",
            params: [
                "name": viewModel.profile.displayName(
                    fallback: preferences.t("settings.defaultProfileName")
                ),
            ]
        )
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

    private var levelAndStreakCard: some View {
        let level = viewModel.vitalityLevelSnapshot
        let streak = viewModel.vitalityStreakSnapshot
        return Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(preferences.t("vitality.levels.title"))
                            .themeFont(.caption, weight: .bold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(preferences.t(level.titleKey))
                            .themeFont(.title3, weight: .bold)
                        Text(preferences.t("vitality.levels.line", params: [
                            "level": String(level.level),
                            "points": String(level.lifetimePoints)
                        ]))
                        .themeFont(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("L\(level.level)")
                        .themeFont(size: 28, weight: .bold)
                        .foregroundStyle(Color("BrandBlue"))
                }
                ProgressView(value: Double(level.progressPercent), total: 100)
                    .tint(Color("BrandBlue"))
                if level.pointsToNextLevel > 0 {
                    Text(preferences.t("vitality.levels.next", params: [
                        "points": String(level.pointsToNextLevel)
                    ]))
                    .themeFont(.caption2)
                    .foregroundStyle(.secondary)
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(preferences.t("vitality.streak.title"))
                            .themeFont(.caption, weight: .bold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(preferences.t("vitality.streak.current", params: [
                            "days": String(streak.currentStreak)
                        ]))
                        .themeFont(.headline, weight: .semibold)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(preferences.t("vitality.streak.shields"))
                            .themeFont(.caption2)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Image(systemName: "shield.fill")
                                .foregroundStyle(streak.shieldsAvailable > 0 ? Color("BrandBlue") : .secondary)
                            Text("\(streak.shieldsAvailable)")
                                .themeFont(.subheadline, weight: .bold)
                        }
                    }
                }
                Text(preferences.t("vitality.streak.hint"))
                    .themeFont(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var workoutBadgesCard: some View {
        let badges = viewModel.workoutTypeBadges
        guard !badges.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text(preferences.t("vitality.workoutBadges.title"))
                        .themeFont(.headline, weight: .semibold)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(badges) { badge in
                                workoutBadgePill(badge)
                            }
                        }
                    }
                }
            }
        )
    }

    private func workoutBadgePill(_ badge: WorkoutTypeBadge) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(preferences.t("history.workoutType.\(badge.workoutType)"))
                .themeFont(.caption, weight: .semibold)
            Text(preferences.t("vitality.workoutBadges.count", params: [
                "count": String(badge.count),
                "target": String(badge.target)
            ]))
            .themeFont(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(badgeTierColor(badge.tier).opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
    }

    private func badgeTierColor(_ tier: String) -> Color {
        switch tier {
        case "gold": return .yellow
        case "silver": return .gray
        case "bronze": return .orange
        default: return Color("BrandBlue")
        }
    }

    private var dailyPointsHeaderCard: some View {
        let record = viewModel.todayVitalityRecord ?? viewModel.dailyRecords.max(by: { $0.date < $1.date })
        guard let record else { return AnyView(EmptyView()) }
        let dailyPointsTarget = VitalityGoals.computeDailyTarget(
            weeklyTarget: viewModel.vitalityGoalSnapshot.weeklyTarget,
            profile: viewModel.profile,
            intensity: MascotConstants.gameplay(viewModel.mascotId).challengeIntensity
        )

        return AnyView(
            Card {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preferences.t("vitality.todayTitle"))
                                .themeFont(.caption, weight: .bold)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            Text(SwimFormatters.formatDateShort(record.date))
                                .themeFont(.subheadline, weight: .semibold)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(record.totalPoints)")
                                .themeFont(size: 44, weight: .bold)
                                .foregroundStyle(Color("BrandBlue"))
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                            Text(preferences.t("vitality.points"))
                                .themeFont(.caption, weight: .semibold)
                                .foregroundStyle(.secondary)
                        }
                    }

                    pointsBreakdownRow(record: record)

                    StepMilestoneProgressBar(
                        steps: record.steps,
                        title: preferences.t("vitality.stepsGoalTitle"),
                        milestoneLabel: { milestone in
                            preferences.t("vitality.badges.step\(milestone / 1000)k")
                        },
                        pointsLabel: { points in
                            preferences.t("vitality.stepsGoalPoints", params: ["points": String(points)])
                        }
                    )

                    SleepMilestoneProgressBar(
                        minutes: record.sleepMinutes,
                        title: preferences.t("vitality.sleepGoalTitle"),
                        hoursLabel: { hours in
                            preferences.t("vitality.sleepGoalHours", params: ["hours": String(hours)])
                        },
                        pointsLabel: { points in
                            preferences.t("vitality.stepsGoalPoints", params: ["points": String(points)])
                        },
                        durationText: sleepDurationText(record.sleepMinutes)
                    )

                    DailyPointsProgressBar(
                        points: record.totalPoints,
                        dailyTarget: dailyPointsTarget,
                        title: preferences.t("vitality.pointsGoalTitle"),
                        halfwayLabel: preferences.t("vitality.pointsGoalHalfway"),
                        goalLabel: preferences.t("vitality.pointsGoalTarget"),
                        stretchLabel: preferences.t("vitality.pointsGoalStretch")
                    )

                    dailyBadgesRow(record: record)
                }
            }
        )
    }

    private func pointsBreakdownRow(record: DailyVitalityRecord) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                stepsBreakdownPill(steps: record.steps)
                breakdownPill(
                    title: preferences.t("vitality.stepPoints"),
                    value: record.stepPoints,
                    color: .teal
                )
                breakdownPill(
                    title: preferences.t("vitality.workoutPoints"),
                    value: record.workoutPoints,
                    color: .orange
                )
                if record.sleepPoints > 0 {
                    breakdownPill(
                        title: preferences.t("vitality.sleepPoints"),
                        value: record.sleepPoints,
                        color: .purple
                    )
                }
            }
        }
    }

    private func stepsBreakdownPill(steps: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(preferences.t("vitality.highlight.steps"))
                .themeFont(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(steps.formatted(.number.grouping(.automatic)))
                .themeFont(.subheadline, weight: .bold)
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func breakdownPill(title: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .themeFont(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("+\(value)")
                .themeFont(.subheadline, weight: .bold)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func sleepDurationText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        if remainder == 0 {
            return preferences.t("vitality.sleepDurationH", params: ["hours": String(hours)])
        }
        return preferences.t("vitality.sleepDurationHm", params: [
            "hours": String(hours),
            "minutes": String(remainder)
        ])
    }

    @ViewBuilder
    private func dailyBadgesRow(record: DailyVitalityRecord) -> some View {
        let feedback = VitalityAnalysis.buildDailyFeedback(
            record: record,
            profile: viewModel.profile,
            t: preferences.translations,
            mascotId: viewModel.mascotId
        )
        if !feedback.badges.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(feedback.badges, id: \.self) { badge in
                        Text(badge)
                            .themeFont(.caption2, weight: .semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color("BrandBlue").opacity(0.12), in: Capsule())
                    }
                }
            }
        }
    }

    private var recentPointsChart: some View {
        let records = Array(viewModel.dailyRecords.suffix(14))
        let average: Double = records.isEmpty
            ? 0
            : Double(records.reduce(0) { $0 + $1.totalPoints }) / Double(records.count)
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                Text(preferences.t("vitality.recentPoints"))
                    .themeFont(.headline, weight: .semibold)
                Chart {
                    if !records.isEmpty {
                        RuleMark(y: .value("Average", average))
                            .foregroundStyle(Color.orange.opacity(0.85))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text(preferences.t("vitality.recentPointsAverage", params: [
                                    "points": String(Int(average.rounded()))
                                ]))
                                .themeFont(.caption2, weight: .semibold)
                                .foregroundStyle(.orange)
                            }
                    }
                    ForEach(records, id: \.id) { record in
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
}
