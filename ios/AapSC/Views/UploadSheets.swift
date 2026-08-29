import SwiftUI

struct MedalCelebrationSheet: View {
    @EnvironmentObject private var preferences: UserPreferencesService
    @Environment(\.appIsDark) private var appIsDark
    let medals: [EvaluatedMedal]
    @Environment(\.dismiss) private var dismiss

    private var profile: ThemeVisualProfile {
        ThemeVisualProfiles.profile(
            code: preferences.themeCode,
            isDark: appIsDark
        )
    }

    private var titleKey: String {
        medals.count == 1 ? "medals.celebration.title" : "medals.celebration.titleMultiple"
    }

    private var subtitle: String {
        if medals.count == 1 {
            return preferences.t("medals.celebration.subtitleOne")
        }
        return preferences.t(
            "medals.celebration.subtitleMultiple",
            params: ["count": "\(medals.count)"]
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ConfettiView()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        Image(systemName: "medal.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(profile.displayAccent)
                            .shadow(color: profile.displayAccent.opacity(0.35), radius: 12)

                        Text(preferences.t(titleKey))
                            .themeFont(.title2, weight: .bold)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)

                        Text(subtitle)
                            .themeFont(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            ForEach(medals) { medal in
                                HStack(spacing: 12) {
                                    MedalIconView(
                                        id: medal.id,
                                        tier: medal.tier,
                                        earned: true,
                                        size: 40
                                    )

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(SwimMedalCopy.title(for: medal.id, t: preferences.translations))
                                            .themeFont(.subheadline, weight: .semibold)
                                            .foregroundStyle(.primary)
                                        Text(medal.tier.capitalized)
                                            .themeFont(.caption, weight: .bold)
                                            .foregroundStyle(profile.displayAccent)
                                    }

                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .themedCard()
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(preferences.t("medals.celebration.continue")) { dismiss() }
                        .foregroundStyle(profile.displayPrimary)
                }
            }
            .themedNavigationBar()
            .themedPageBackground()
        }
        .presentationDetents([.medium, .large])
    }
}

struct DuplicateSessionAlert: View {
    @EnvironmentObject private var preferences: UserPreferencesService
    let duplicate: SwimSession
    let onCancel: () -> Void
    let onSaveAnyway: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(preferences.t("upload.duplicateTitle"))
                .themeFont(.headline, weight: .semibold)
            Text(preferences.t("upload.duplicateMessage", params: [
                "date": SwimFormatters.formatDateLong(duplicate.date)
            ]))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            HStack {
                Button(preferences.t("common.cancel"), action: onCancel)
                    .buttonStyle(.bordered)
                Button(preferences.t("upload.saveSession"), action: onSaveAnyway)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

struct SearchingNewSessionsSheet: View {
    @EnvironmentObject private var preferences: UserPreferencesService

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)
            Text(preferences.t("launch.searchingNewSessions"))
                .themeFont(.headline, weight: .semibold)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }
}

struct SessionFeedbackSheet: View {
    @EnvironmentObject private var viewModel: SwimViewModel
    @EnvironmentObject private var preferences: UserPreferencesService
    let feedback: SessionFeedbackSummary
    var isLoading: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                SessionFeedbackCard(
                    feedback: feedback,
                    isLoading: isLoading
                )
                .padding()
            }
            .navigationTitle(preferences.t("feedback.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(preferences.t("settings.confirm")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
