import SwiftUI

struct SecretSettingsSheet: View {
    @EnvironmentObject private var viewModel: SwimViewModel
    @EnvironmentObject private var preferences: UserPreferencesService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(preferences.t("settings.secretUnlockHint"))
                        .themeFont(.caption)
                        .foregroundStyle(.secondary)
                }

                Section(preferences.t("settings.secretCheatsSection")) {
                    Toggle(preferences.t("settings.secretUnlockAllMedals"), isOn: cheatBinding(\.allMedalsUnlocked))
                    Toggle(preferences.t("settings.secretPreviewMonthlyMedals"), isOn: cheatBinding(\.previewMonthlyMedals))
                }
            }
            .navigationTitle(preferences.t("settings.secretTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(preferences.t("settings.cancel")) { dismiss() }
                }
            }
        }
    }

    private func cheatBinding(_ keyPath: WritableKeyPath<SwimCheats, Bool>) -> Binding<Bool> {
        Binding(
            get: { viewModel.cheats[keyPath: keyPath] },
            set: { newValue in
                viewModel.updateCheats { $0[keyPath: keyPath] = newValue }
            }
        )
    }
}
