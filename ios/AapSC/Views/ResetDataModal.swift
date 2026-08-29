import SwiftUI

struct ResetDataModal: View {
    @EnvironmentObject private var preferences: UserPreferencesService
    @Environment(\.dismiss) private var dismiss

    let sessionCount: Int
    let onConfirm: () -> Void

    @State private var step = 1
    @State private var typed = ""

    private var confirmPhrase: String {
        preferences.t("settings.resetConfirmPhrase")
    }

    private var phraseOk: Bool {
        typed.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            == confirmPhrase.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(preferences.t("settings.resetProgress", params: [
                        "step": String(step),
                        "total": "3"
                    ]))
                    .themeFont(.caption, weight: .semibold)
                    .foregroundStyle(.red)
                    .textCase(.uppercase)
                }

                Text(stepTitle)
                    .themeFont(.title2, weight: .bold)

                Text(stepMessage)
                    .themeFont(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if step == 3 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(preferences.t("settings.resetTypePrompt", params: ["phrase": confirmPhrase]))
                            .themeFont(.subheadline, weight: .medium)
                        TextField(preferences.t("settings.resetTypePlaceholder"), text: $typed)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Spacer()

                HStack(spacing: 12) {
                    Button(preferences.t("settings.cancel")) {
                        resetState()
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)

                    Button(continueLabel) {
                        if step < 3 {
                            step += 1
                        } else if phraseOk {
                            onConfirm()
                            resetState()
                            dismiss()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(step == 3 && !phraseOk)
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private var stepTitle: String {
        switch step {
        case 1: return preferences.t("settings.resetStep1Title")
        case 2: return preferences.t("settings.resetStep2Title")
        default: return preferences.t("settings.resetStep3Title")
        }
    }

    private var stepMessage: String {
        switch step {
        case 1:
            return preferences.t("settings.resetStep1Desc") + " "
                + preferences.t("settings.resetSessionCount", params: ["count": String(sessionCount)])
        case 2:
            return preferences.t("settings.resetStep2Desc")
        default:
            return preferences.t("settings.resetStep3Desc")
        }
    }

    private var continueLabel: String {
        switch step {
        case 1: return preferences.t("settings.resetStep1Continue")
        case 2: return preferences.t("settings.resetStep2Continue")
        default: return preferences.t("settings.clearButton")
        }
    }

    private func resetState() {
        step = 1
        typed = ""
    }
}
