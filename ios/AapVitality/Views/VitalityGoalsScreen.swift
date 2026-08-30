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
                        WeeklyGoalCard(snapshot: snapshot)
                        MonthlyGoalCard(snapshot: snapshot)
                        YearlyGoalCard(snapshot: snapshot)

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
}

private struct MonthlyGoalCard: View {
    @EnvironmentObject private var preferences: UserPreferencesService

    let snapshot: VitalityGoalSnapshot
    @State private var isExpanded = false

    private let accent = Color("BrandBlue")

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        isExpanded.toggle()
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(preferences.t("goals.monthly"))
                                .themeFont(.headline, weight: .semibold)
                            Spacer()
                            Text("\(snapshot.monthlyPercent)%")
                                .themeFont(.title3, weight: .bold)
                                .foregroundStyle(accent)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(
                            value: Double(min(snapshot.monthlyEarned, snapshot.monthlyTarget)),
                            total: Double(max(snapshot.monthlyTarget, 1))
                        )
                        .tint(accent)
                        Text(preferences.t("goals.progressLine", params: [
                            "current": String(snapshot.monthlyEarned),
                            "target": String(snapshot.monthlyTarget)
                        ]))
                        .themeFont(.caption)
                        .foregroundStyle(.secondary)
                        if snapshot.challengeBonusPoints > 0 {
                            Text(preferences.t("goals.challengeBonus", params: [
                                "points": String(snapshot.challengeBonusPoints)
                            ]))
                            .themeFont(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint(preferences.t(isExpanded ? "goals.monthlyCollapseHint" : "goals.monthlyExpandHint"))

                if isExpanded {
                    EarlyFinishBonusView(
                        earlyFinish: snapshot.earlyFinish,
                        label: { preferences.t($0, params: $1) }
                    )

                    Divider()
                    MonthlyChallengesCardView()
                }
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

private struct WeeklyGoalCard: View {
    @EnvironmentObject private var viewModel: VitalityViewModel
    @EnvironmentObject private var preferences: UserPreferencesService

    let snapshot: VitalityGoalSnapshot
    @State private var isExpanded = false

    private let accent = Color.teal

    var body: some View {
        let days = VitalityGoals.weeklyDayBreakdown(
            records: viewModel.dailyRecords,
            weekKey: snapshot.weekKey
        )
        let maxPoints = max(days.map(\.totalPoints).max() ?? 0, 1)

        Card {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        isExpanded.toggle()
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(preferences.t("goals.weekly"))
                                .themeFont(.headline, weight: .semibold)
                            Spacer()
                            Text("\(snapshot.weeklyPercent)%")
                                .themeFont(.title3, weight: .bold)
                                .foregroundStyle(accent)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(
                            value: Double(min(snapshot.weeklyEarned, snapshot.weeklyTarget)),
                            total: Double(max(snapshot.weeklyTarget, 1))
                        )
                        .tint(accent)
                        Text(preferences.t("goals.progressLine", params: [
                            "current": String(snapshot.weeklyEarned),
                            "target": String(snapshot.weeklyTarget)
                        ]))
                        .themeFont(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint(preferences.t(isExpanded ? "goals.weeklyCollapseHint" : "goals.weeklyExpandHint"))

                if isExpanded {
                    Divider()
                    Text(preferences.t("goals.weeklyBreakdownTitle"))
                        .themeFont(.caption, weight: .bold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    VStack(spacing: 0) {
                        ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                            if index > 0 {
                                Divider().opacity(0.5)
                            }
                            dayRow(day, maxPoints: maxPoints)
                        }
                    }
                }
            }
        }
    }

    private func dayRow(_ day: WeeklyDayPoint, maxPoints: Int) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(weekdayLabel(day.date))
                        .themeFont(.subheadline, weight: day.isToday ? .bold : .semibold)
                    if day.isToday {
                        Text(preferences.t("goals.weeklyToday"))
                            .themeFont(.caption2, weight: .semibold)
                            .foregroundStyle(accent)
                    }
                }
                Text(dayDetail(day))
                    .themeFont(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                Text(day.isFuture ? "—" : "\(day.totalPoints)")
                    .themeFont(.subheadline, weight: .bold)
                    .foregroundStyle(day.isToday ? accent : .primary)
                    .monospacedDigit()
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(accent.opacity(0.12))
                        if !day.isFuture, day.totalPoints > 0 {
                            Capsule()
                                .fill(accent)
                                .frame(width: geometry.size.width * CGFloat(day.totalPoints) / CGFloat(maxPoints))
                        }
                    }
                }
                .frame(width: 56, height: 5)
            }
        }
        .padding(.vertical, 8)
        .opacity(day.isFuture ? 0.45 : 1)
    }

    private func weekdayLabel(_ dateKey: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        let formatter = DateFormatter()
        formatter.locale = preferences.locale
        formatter.dateFormat = "EEE d"
        guard let date = parser.date(from: dateKey) else { return dateKey }
        return formatter.string(from: date)
    }

    private func dayDetail(_ day: WeeklyDayPoint) -> String {
        if day.isFuture {
            return preferences.t("goals.weeklyUpcoming")
        }
        if day.totalPoints <= 0 {
            return preferences.t("goals.weeklyRestDay")
        }
        return preferences.t("goals.weeklyBreakdownLine", params: [
            "steps": String(day.stepPoints),
            "workouts": String(day.workoutPoints),
            "sleep": String(day.sleepPoints)
        ])
    }
}

private struct YearlyGoalCard: View {
    @EnvironmentObject private var viewModel: VitalityViewModel
    @EnvironmentObject private var preferences: UserPreferencesService

    let snapshot: VitalityGoalSnapshot
    @State private var isExpanded = false

    private let accent = Color.orange

    var body: some View {
        let months = VitalityGoals.yearlyMonthBreakdown(
            records: viewModel.dailyRecords,
            yearKey: snapshot.yearKey
        )
        let maxPoints = max(months.map(\.totalPoints).max() ?? 0, 1)

        Card {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        isExpanded.toggle()
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(preferences.t("goals.yearly"))
                                .themeFont(.headline, weight: .semibold)
                            Spacer()
                            Text("\(snapshot.yearlyPercent)%")
                                .themeFont(.title3, weight: .bold)
                                .foregroundStyle(accent)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(
                            value: Double(min(snapshot.yearlyEarned, snapshot.yearlyTarget)),
                            total: Double(max(snapshot.yearlyTarget, 1))
                        )
                        .tint(accent)
                        Text(preferences.t("goals.progressLine", params: [
                            "current": String(snapshot.yearlyEarned),
                            "target": String(snapshot.yearlyTarget)
                        ]))
                        .themeFont(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint(preferences.t(isExpanded ? "goals.yearlyCollapseHint" : "goals.yearlyExpandHint"))

                if isExpanded {
                    Divider()
                    Text(preferences.t("goals.yearlyBreakdownTitle"))
                        .themeFont(.caption, weight: .bold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    VStack(spacing: 0) {
                        ForEach(Array(months.enumerated()), id: \.element.id) { index, month in
                            if index > 0 {
                                Divider().opacity(0.5)
                            }
                            monthRow(month, maxPoints: maxPoints)
                        }
                    }
                }
            }
        }
    }

    private func monthRow(_ month: YearlyMonthPoint, maxPoints: Int) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(monthLabel(month.monthKey))
                        .themeFont(.subheadline, weight: month.isCurrentMonth ? .bold : .semibold)
                    if month.isCurrentMonth {
                        Text(preferences.t("goals.yearlyThisMonth"))
                            .themeFont(.caption2, weight: .semibold)
                            .foregroundStyle(accent)
                    }
                }
                Text(monthDetail(month))
                    .themeFont(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                Text(month.isFuture ? "—" : "\(month.totalPoints)")
                    .themeFont(.subheadline, weight: .bold)
                    .foregroundStyle(month.isCurrentMonth ? accent : .primary)
                    .monospacedDigit()
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(accent.opacity(0.12))
                        if !month.isFuture, month.totalPoints > 0 {
                            Capsule()
                                .fill(accent)
                                .frame(width: geometry.size.width * CGFloat(month.totalPoints) / CGFloat(maxPoints))
                        }
                    }
                }
                .frame(width: 56, height: 5)
            }
        }
        .padding(.vertical, 8)
        .opacity(month.isFuture ? 0.45 : 1)
    }

    private func monthLabel(_ monthKey: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        let formatter = DateFormatter()
        formatter.locale = preferences.locale
        formatter.dateFormat = "MMMM"
        guard let date = parser.date(from: "\(monthKey)-01") else { return monthKey }
        return formatter.string(from: date)
    }

    private func monthDetail(_ month: YearlyMonthPoint) -> String {
        if month.isFuture {
            return preferences.t("goals.weeklyUpcoming")
        }
        if month.totalPoints <= 0 {
            return preferences.t("goals.weeklyRestDay")
        }
        return preferences.t("goals.weeklyBreakdownLine", params: [
            "steps": String(month.stepPoints),
            "workouts": String(month.workoutPoints),
            "sleep": String(month.sleepPoints)
        ])
    }
}
