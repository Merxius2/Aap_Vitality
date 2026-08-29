import SwiftUI

struct UploadScreen: View {
    @EnvironmentObject private var viewModel: VitalityViewModel
    @EnvironmentObject private var preferences: UserPreferencesService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Card {
                        VStack(spacing: 16) {
                            Button {
                                Task { await viewModel.syncVitalityData(requestAuthorizationIfNeeded: true) }
                            } label: {
                                Label(preferences.t("upload.healthImport"), systemImage: "arrow.triangle.2.circlepath")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color("BrandBlue"))
                            .disabled(viewModel.isSyncingHealthKit)

                            if viewModel.isSyncingHealthKit {
                                ProgressView(preferences.t("upload.healthSyncing"))
                            }

                            if let message = viewModel.healthKitSyncMessage {
                                Text(message)
                                    .themeFont(.footnote)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Text(preferences.t("upload.healthHint"))
                                .themeFont(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                Label(preferences.t("upload.scoringSteps"), systemImage: "figure.walk")
                                Label(preferences.t("upload.scoringWorkouts"), systemImage: "heart.fill")
                                Label(preferences.t("upload.scoringZones"), systemImage: "waveform.path.ecg")
                            }
                            .themeFont(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }

                    if let record = viewModel.todayVitalityRecord {
                        Card {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(preferences.t("vitality.todayTitle"))
                                    .themeFont(.headline, weight: .semibold)
                                Text(preferences.t("vitality.insights.dailyTotal", params: [
                                    "points": String(record.totalPoints)
                                ]))
                                .themeFont(.subheadline)
                                Text(preferences.t("history.workoutCount", params: [
                                    "count": String(record.workouts.count)
                                ]))
                                .themeFont(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(preferences.t("common.close")) { dismiss() }
                }
            }
            .themedPageBackground()
        }
    }
}
