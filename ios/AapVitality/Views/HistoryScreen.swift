import SwiftUI

struct HistoryScreen: View {
    @EnvironmentObject private var viewModel: VitalityViewModel
    @EnvironmentObject private var preferences: UserPreferencesService
    @State private var expandedId: String?
    @State private var deleteId: String?
    @State private var selectedDate: String?

    private var sorted: [DailyVitalityRecord] {
        viewModel.dailyRecords.sorted { $0.date > $1.date }
    }

    private var filtered: [DailyVitalityRecord] {
        guard let selectedDate else { return sorted }
        return sorted.filter { $0.date == selectedDate }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if !sorted.isEmpty {
                        VitalityCalendarView(records: viewModel.dailyRecords, selectedDate: $selectedDate)

                        if let selectedDate {
                            HStack {
                                Text(preferences.t("history.filterDate", params: [
                                    "date": SwimFormatters.formatDateLong(selectedDate)
                                ]))
                                    .themeFont(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button(preferences.t("history.clearFilter")) { self.selectedDate = nil }
                                    .themeFont(.caption, weight: .semibold)
                            }
                            .padding(.horizontal, 4)
                        }
                    }

                    if sorted.isEmpty {
                        ContentUnavailableView(
                            preferences.t("history.empty"),
                            systemImage: "clock.arrow.circlepath",
                            description: Text(preferences.t("history.subtitle"))
                        )
                        .padding(.top, 40)
                    } else if filtered.isEmpty {
                        Text(preferences.t("history.noSessionsOnDate"))
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        ForEach(filtered) { record in
                            HistoryVitalityCard(
                                record: record,
                                isExpanded: expandedId == record.id,
                                onToggle: {
                                    expandedId = expandedId == record.id ? nil : record.id
                                },
                                onDelete: { deleteId = record.id }
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(preferences.t("history.title"))
            .navigationBarTitleDisplayMode(.inline)
            .swimTopBarActions()
            .themedNavigationBar()
            .confirmationDialog(
                preferences.t("history.deleteConfirm"),
                isPresented: Binding(
                    get: { deleteId != nil },
                    set: { if !$0 { deleteId = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(preferences.t("history.delete"), role: .destructive) {
                    if let deleteId {
                        viewModel.removeDailyRecord(date: deleteId)
                        if expandedId == deleteId { expandedId = nil }
                    }
                    self.deleteId = nil
                }
                Button(preferences.t("common.cancel"), role: .cancel) { deleteId = nil }
            }
            .themedPageBackground()
        }
    }
}

private struct HistoryVitalityCard: View {
    @EnvironmentObject private var preferences: UserPreferencesService
    let record: DailyVitalityRecord
    let isExpanded: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Button(action: onToggle) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(SwimFormatters.formatDateLong(record.date))
                                .themeFont(.headline, weight: .semibold)
                            Text(summaryLine)
                                .themeFont(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if isExpanded {
                    Divider()
                    detailGrid
                    if !record.workouts.isEmpty {
                        ForEach(record.workouts) { workout in
                            workoutRow(workout)
                        }
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label(preferences.t("history.delete"), systemImage: "trash")
                    }
                    .themeFont(.subheadline)
                }
            }
        }
    }

    private var summaryLine: String {
        let steps = preferences.t("vitality.highlight.steps") + ": \(record.steps)"
        let points = preferences.t("vitality.highlight.points") + ": \(record.totalPoints)"
        let workouts = preferences.t("history.workoutCount", params: ["count": String(record.workouts.count)])
        return "\(steps) · \(points) · \(workouts)"
    }

    private var detailGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            detailItem(preferences.t("vitality.stepPoints"), value: "\(record.stepPoints)")
            detailItem(preferences.t("vitality.workoutPoints"), value: "\(record.workoutPoints)")
            detailItem(preferences.t("vitality.highlight.steps"), value: "\(record.steps)")
            detailItem(preferences.t("vitality.highlight.points"), value: "\(record.totalPoints)")
        }
        .themeFont(.caption)
    }

    private func workoutRow(_ workout: VitalityWorkout) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(workoutLabel(for: workout.workoutType))
                    .themeFont(.caption, weight: .semibold)
                Text(SwimFormatters.formatDuration(workout.durationSec))
                    .themeFont(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(workout.pointsEarned) " + preferences.t("vitality.points"))
                .themeFont(.caption, weight: .bold)
                .foregroundStyle(Color("BrandBlue"))
        }
        .padding(.vertical, 4)
    }

    private func detailItem(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func workoutLabel(for type: String) -> String {
        let key = "history.workoutType.\(type)"
        let localized = preferences.t(key)
        if localized == key {
            return type.replacingOccurrences(of: "_", with: " ").capitalized
        }
        return localized
    }
}
