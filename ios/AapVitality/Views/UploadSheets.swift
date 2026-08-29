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
