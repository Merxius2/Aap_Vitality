import SwiftUI

struct MonthlyChallengesCardView: View {
    @EnvironmentObject private var viewModel: VitalityViewModel
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

struct VitalityCalendarView: View {
    @EnvironmentObject private var preferences: UserPreferencesService
    let records: [DailyVitalityRecord]
    @Binding var selectedDate: String?

    @State private var viewYear: Int
    @State private var viewMonth: Int

    init(records: [DailyVitalityRecord], selectedDate: Binding<String?>) {
        self.records = records
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

    private var activityByDate: [String: Int] {
        records.reduce(into: [:]) { result, record in
            let level: Int
            switch record.totalPoints {
            case 80...: level = 3
            case 40..<80: level = 2
            case 1..<40: level = 1
            default: level = 0
            }
            result[record.date] = max(result[record.date] ?? 0, level)
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
            result.append(CalendarCell(day: day, dateKey: dateKey, count: activityByDate[dateKey] ?? 0, isToday: dateKey == todayKey))
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
        let mondayIndex = 1
        return Array(symbols[mondayIndex...] + symbols[..<mondayIndex])
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
