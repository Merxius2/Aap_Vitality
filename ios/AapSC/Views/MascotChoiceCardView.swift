import SwiftUI

struct MascotChoiceCardView: View {
    @EnvironmentObject private var preferences: UserPreferencesService
    @Environment(\.appIsDark) private var appIsDark
    @Environment(\.themeColors) private var themeColors

    let mascotId: String
    let isActive: Bool
    let isLocked: Bool
    let isDisabled: Bool
    let unlockHint: String?
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    MascotCharacterView(
                        mascotId: mascotId,
                        animated: isActive && !isLocked,
                        size: 120
                    )
                    .padding(.top, 8)
                    .opacity(isLocked ? 0.75 : 1)

                    statusBadge
                        .padding(10)
                }

                Text(preferences.t(MascotConstants.nameKey(mascotId)))
                    .themeFont(.title3, weight: .bold)
                    .foregroundStyle(.primary)
                    .padding(.top, 4)

                MascotLevelBadgeView(level: MascotConstants.coachedLevel(mascotId))
                    .padding(.top, 6)

                traitRow
                    .padding(.top, 8)

                Text(preferences.t(MascotConstants.descKey(mascotId)))
                    .themeFont(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)

                if let unlockHint {
                    Text(unlockHint)
                        .themeFont(.caption2)
                        .foregroundStyle(Color(red: 0.92, green: 0.7, blue: 0.03))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }

                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .themeFont(.caption2)
                    Text(preferences.t(MascotConstants.rulesKey(mascotId)))
                        .themeFont(.caption2)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isActive && !isLocked ? 2 : 1)
            )
            .overlay {
                if isActive && !isLocked {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(themeColors.primary.opacity(0.3), lineWidth: 3)
                }
            }
            .opacity(isDisabled ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    @ViewBuilder
    private var statusBadge: some View {
        if isLocked {
            Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.gray.opacity(0.65), in: Circle())
        } else if isActive {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(themeColors.primary, in: Circle())
        }
    }

    private var traitRow: some View {
        HStack(spacing: 6) {
            ForEach(MascotConstants.traitKeys(mascotId), id: \.self) { key in
                Text(preferences.t(key))
                    .font(.system(size: 10, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.4)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Color(.secondarySystemBackground),
                        in: Capsule()
                    )
            }
        }
    }

    private var cardBackground: Color {
        appIsDark
            ? Color(red: 0.27, green: 0.27, blue: 0.27)
            : Color(.secondarySystemGroupedBackground)
    }

    private var borderColor: Color {
        if isActive && !isLocked {
            return themeColors.primary
        }
        return appIsDark
            ? Color.white.opacity(0.1)
            : Color.black.opacity(0.12)
    }
}

struct MascotSettingsSection: View {
    @EnvironmentObject private var viewModel: SwimViewModel
    @EnvironmentObject private var preferences: UserPreferencesService
    @Environment(\.themeColors) private var themeColors
    @Environment(\.appIsDark) private var appIsDark

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .themeFont(.title3, weight: .semibold)
                    .foregroundStyle(themeColors.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(preferences.t("settings.mascotTitle"))
                        .themeFont(.headline, weight: .semibold)
                    Text(preferences.t("settings.mascotDesc"))
                        .themeFont(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let blockedReason = switchBlockedReason {
                Text(preferences.t("settings.mascotSwitchBlocked.\(blockedReason)"))
                    .themeFont(.caption)
                    .foregroundStyle(blockedBannerForeground)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(blockedBannerBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(blockedBannerBorder, lineWidth: 1)
                    )
            } else {
                Text(preferences.t("settings.mascotSwitchHint"))
                    .themeFont(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                ForEach(MascotConstants.ids, id: \.self) { mascotId in
                    mascotCard(for: mascotId)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text(
                    preferences.t(
                        "settings.mascotActiveCoach",
                        params: ["name": MascotConstants.displayName(viewModel.mascotId, t: preferences.translations)]
                    )
                )
                .themeFont(.subheadline, weight: .medium)
                .foregroundStyle(.secondary)

                MascotCoachView(
                    mascotId: viewModel.mascotId,
                    message: previewMessage,
                    level: MascotConstants.coachedLevel(viewModel.mascotId),
                    bubbleTone: viewModel.mascotId == "fins" ? .levelUp : .default,
                    coachName: MascotConstants.displayName(viewModel.mascotId, t: preferences.translations),
                    showStage: true,
                    size: 190,
                    animated: true,
                    layout: .stacked
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func mascotCard(for mascotId: String) -> some View {
        let unlockStatus = MascotUnlock.unlockStatus(
            mascotId: mascotId,
            profile: viewModel.profile,
            sessions: viewModel.sessions,
            monthlyChallengeRerolls: viewModel.monthlyChallengeRerolls
        )
        let locked = !unlockStatus.unlocked
        let switchCheck = MascotUnlock.canSwitchMascot(
            profile: viewModel.profile,
            sessions: viewModel.sessions,
            nextMascotId: mascotId,
            currentMascotId: viewModel.mascotId
        )
        let disabled = locked || !switchCheck.allowed

        MascotChoiceCardView(
            mascotId: mascotId,
            isActive: viewModel.mascotId == mascotId,
            isLocked: locked,
            isDisabled: disabled,
            unlockHint: unlockHint(for: mascotId, unlockStatus: unlockStatus)
        ) {
            _ = viewModel.switchMascot(mascotId)
        }
    }

    private var switchBlockedReason: String? {
        let monthKey = SwimMonthlyChallenges.getMonthKey()
        if viewModel.profile.mascotSwitchMonthKey == monthKey {
            return "alreadySwitched"
        }
        let switchWindow = MascotUnlock.canSwitchMascot(
            profile: viewModel.profile,
            sessions: viewModel.sessions,
            monthKey: monthKey,
            nextMascotId: viewModel.mascotId,
            currentMascotId: viewModel.mascotId
        )
        if switchWindow.reason == "afterFirstSession" {
            return "afterFirstSession"
        }
        return nil
    }

    private var previewMessage: String {
        let template = preferences.t(MascotConstants.previewKey(viewModel.mascotId))
        let name = viewModel.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = name.isEmpty ? preferences.t("settings.defaultSwimmerName") : name
        return template.replacingOccurrences(of: "{name}", with: displayName)
    }

    private func unlockHint(for mascotId: String, unlockStatus: (unlocked: Bool, paceMet: Bool, medalsMet: Bool, paceLevel: SwimLevel, monthlyMedals: Int)) -> String? {
        guard !unlockStatus.unlocked,
              let requirements = MascotUnlock.unlockRequirements[mascotId],
              let minPaceLevel = requirements.minPaceLevel else {
            return nil
        }
        let paceLabel = preferences.t("benchmark.levels.\(minPaceLevel)")
        return preferences.t(
            "settings.mascotUnlockHint",
            params: [
                "pace": paceLabel,
                "medals": String(requirements.minMonthlyMedals),
            ]
        )
    }

    private var blockedBannerForeground: Color {
        appIsDark
            ? Color(red: 1.0, green: 0.92, blue: 0.75)
            : Color(red: 0.55, green: 0.35, blue: 0.05)
    }

    private var blockedBannerBackground: Color {
        appIsDark
            ? Color(red: 0.25, green: 0.16, blue: 0.04)
            : Color(red: 1.0, green: 0.95, blue: 0.8)
    }

    private var blockedBannerBorder: Color {
        appIsDark
            ? Color(red: 0.55, green: 0.35, blue: 0.1)
            : Color(red: 0.95, green: 0.8, blue: 0.45)
    }
}
