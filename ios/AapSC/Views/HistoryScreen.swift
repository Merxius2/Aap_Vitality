import SwiftUI

struct HistoryScreen: View {
    @EnvironmentObject private var viewModel: SwimViewModel
    @EnvironmentObject private var preferences: UserPreferencesService
    @State private var expandedId: String?
    @State private var deleteId: String?
    @State private var selectedDate: String?

    private var sorted: [SwimSession] {
        viewModel.sessions.sorted { $0.date > $1.date }
    }

    private var filtered: [SwimSession] {
        guard let selectedDate else { return sorted }
        return sorted.filter { $0.date == selectedDate }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if !sorted.isEmpty {
                        SessionCalendarView(sessions: viewModel.sessions, selectedDate: $selectedDate)

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
                        ForEach(filtered) { session in
                            HistorySessionCard(
                                session: session,
                                isExpanded: expandedId == session.id,
                                onToggle: {
                                    expandedId = expandedId == session.id ? nil : session.id
                                },
                                onToggleStats: { include in
                                    viewModel.updateSession(id: session.id) { $0.excludeFromStats = !include }
                                },
                                onDelete: { deleteId = session.id }
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
                        viewModel.removeSession(id: deleteId)
                        if expandedId == deleteId { expandedId = nil }
                    }
                    deleteId = nil
                }
                Button(preferences.t("common.cancel"), role: .cancel) { deleteId = nil }
            }
            .themedPageBackground()
        }
    }
}

private struct HistorySessionCard: View {
    @EnvironmentObject private var preferences: UserPreferencesService
    let session: SwimSession
    let isExpanded: Bool
    let onToggle: () -> Void
    let onToggleStats: (Bool) -> Void
    let onDelete: () -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Button(action: onToggle) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(SwimFormatters.formatDateLong(session.date))
                                    .themeFont(.headline, weight: .semibold)
                                if session.excludeFromStats {
                                    Text(preferences.t("history.excludedBadge"))
                                        .themeFont(.caption2, weight: .bold)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(.systemGray5), in: Capsule())
                                }
                            }
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
                    Toggle(preferences.t("history.includeInStats"), isOn: Binding(
                        get: { !session.excludeFromStats },
                        set: onToggleStats
                    ))
                    Button(role: .destructive, action: onDelete) {
                        Label(preferences.t("history.delete"), systemImage: "trash")
                    }
                    .themeFont(.subheadline)
                }
            }
        }
        .opacity(session.excludeFromStats ? 0.85 : 1)
    }

    private var summaryLine: String {
        let m = session.metrics
        return "\(SwimFormatters.formatDistance(m.distanceM)) · \(SwimFormatters.formatPace(m.paceSecPer100m)) · \(SwimFormatters.formatDuration(m.durationSec))"
    }

    private var detailGrid: some View {
        let m = session.metrics
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            detailItem(preferences.t("progress.activeKcal"), value: m.activeKcal.map { "\($0) " + preferences.t("common.kcal") } ?? "—")
            detailItem(preferences.t("progress.totalKcal"), value: m.totalKcal.map { "\($0) " + preferences.t("common.kcal") } ?? "—")
            detailItem(preferences.t("upload.fields.heartRate"), value: m.avgHeartRate.map { "\($0) " + preferences.t("common.bpm") } ?? "—")
            detailItem(preferences.t("upload.fields.laps"), value: m.laps.map(String.init) ?? "—")
            detailItem(preferences.t("upload.fields.location"), value: m.location.isEmpty ? "—" : m.location)
            detailItem(preferences.t("upload.fields.timeRange"), value: m.timeRange.isEmpty ? "—" : m.timeRange)
        }
        .themeFont(.caption)
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
}
