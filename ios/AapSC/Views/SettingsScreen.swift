import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject private var viewModel: SwimViewModel
    @EnvironmentObject private var preferences: UserPreferencesService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openUpload) private var openUpload
    @Environment(\.appIsDark) private var appIsDark

    var embedded: Bool = false

    @State private var showSecretSettings = false

    private var profile: ThemeVisualProfile {
        ThemeVisualProfiles.profile(
            code: preferences.themeCode,
            isDark: appIsDark
        )
    }

    private var tabBarScrollInset: CGFloat {
        guard embedded else { return 0 }
        return TabBarLayout.totalHeight(for: profile.tabBar) + TabBarLayout.bottomPadding + 24
    }

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                mascotSection
                languageSection
                themeSection
                wallpaperSection
                darkModeSection
                uploadSection
                ambientSection
            }
            .safeAreaPadding(.bottom, tabBarScrollInset)
            .navigationTitle(preferences.t("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !embedded {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(preferences.t("settings.cancel")) { dismiss() }
                    }
                }
            }
            .onTapGesture(count: 3) {
                showSecretSettings = true
            }
            .sheet(isPresented: $showSecretSettings) {
                SecretSettingsSheet()
            }
            .themedNavigationBar()
            .themedPageBackground()
        }
    }

    private var profileSection: some View {
        Section(preferences.t("settings.profileTitle")) {
            TextField(preferences.t("settings.swimmerNamePlaceholder"), text: binding(\.name))
                .themedListRowBackground()
            Picker(preferences.t("settings.sex"), selection: binding(\.sex)) {
                Text(preferences.t("settings.sexMale")).tag("male")
                Text(preferences.t("settings.sexFemale")).tag("female")
            }
            .themedListRowBackground()
            Stepper(value: ageBinding, in: 10...99) {
                Text(preferences.t("settings.age") + ": \(viewModel.profile.age)")
            }
            .themedListRowBackground()
        }
    }

    private var mascotSection: some View {
        Section {
            MascotSettingsSection()
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
    }

    private var languageSection: some View {
        Section(preferences.t("settings.language")) {
            Picker(preferences.t("settings.language"), selection: languageBinding) {
                ForEach(TranslationService.supportedLanguages, id: \.self) { code in
                    Text(preferences.translations.languageDisplayName(code)).tag(code)
                }
            }
            .themedListRowBackground()
        }
    }

    private var themeSection: some View {
        Section(preferences.t("settings.theme")) {
            ForEach(AppThemes.all) { theme in
                Button {
                    preferences.setTheme(theme.code)
                } label: {
                    HStack(spacing: 12) {
                        ThemePreviewBar(theme: theme, height: 28)
                            .frame(width: 72)
                        Text(preferences.t(theme.nameKey))
                        Spacer()
                        if preferences.themeCode == theme.code {
                            Image(systemName: "checkmark")
                                .foregroundStyle(profile.displayPrimary)
                        }
                    }
                }
                .themedListRowBackground()
            }
        }
    }

    private var wallpaperSection: some View {
        Section {
            Text(preferences.t("settings.wallpaperDesc"))
                .themeFont(.caption)
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    Button {
                        viewModel.updateProfile { $0.activeWallpaper = nil }
                    } label: {
                        WallpaperPreviewTile(
                            id: nil,
                            title: preferences.t("settings.wallpaperDefault"),
                            isSelected: viewModel.profile.activeWallpaper == nil,
                            themeCode: preferences.themeCode,
                            isDark: appIsDark
                        )
                    }
                    .buttonStyle(.plain)

                    ForEach(WallpaperCatalog.allIds, id: \.self) { id in
                        Button {
                            viewModel.updateProfile { $0.activeWallpaper = id }
                        } label: {
                            WallpaperPreviewTile(
                                id: id,
                                title: preferences.t(WallpaperCatalog.nameKey(for: id)),
                                isSelected: viewModel.profile.activeWallpaper == id,
                                themeCode: preferences.themeCode,
                                isDark: appIsDark
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 20)
            }
            .scrollClipDisabled()
            .listRowInsets(EdgeInsets(top: 8, leading: -20, bottom: 12, trailing: -20))
            .listRowBackground(Color.clear)
        } header: {
            Text(preferences.t("settings.wallpaperTitle"))
        }
    }

    private var darkModeSection: some View {
        Section(preferences.t("settings.darkMode")) {
            Toggle(preferences.t("settings.autoDarkMode"), isOn: autoDarkBinding)
                .themedListRowBackground()
            if !preferences.isAutoDarkMode {
                Toggle(preferences.t("settings.darkMode"), isOn: darkModeBinding)
                    .themedListRowBackground()
            }
        }
    }

    private var uploadSection: some View {
        Section(preferences.t("settings.uploadTitle")) {
            Text(preferences.t("settings.uploadDesc"))
                .themeFont(.caption)
                .foregroundStyle(.secondary)
                .themedListRowBackground()
            Button(preferences.t("settings.uploadCta")) {
                if embedded {
                    openUpload()
                } else {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        openUpload()
                    }
                }
            }
            .themedListRowBackground()
        }
    }

    private var ambientSection: some View {
        Section(preferences.t("settings.ambientTitle")) {
            Text(preferences.t("settings.ambientDesc"))
                .themeFont(.caption)
                .foregroundStyle(.secondary)
                .themedListRowBackground()

            Picker(preferences.t("settings.activeAmbient"), selection: ambientBinding) {
                Text(preferences.t("settings.ambientDefault")).tag(Optional<String>.none)
                ForEach(AmbientCatalog.allIds, id: \.self) { id in
                    Text(preferences.t(AmbientCatalog.nameKey(for: id))).tag(Optional(id))
                }
            }
            .themedListRowBackground()
        }
    }

    private var languageBinding: Binding<String> {
        Binding(
            get: { preferences.language },
            set: { preferences.setLanguage($0) }
        )
    }

    private var autoDarkBinding: Binding<Bool> {
        Binding(
            get: { preferences.isAutoDarkMode },
            set: { preferences.setDarkMode(preferences.isDarkMode, auto: $0) }
        )
    }

    private var darkModeBinding: Binding<Bool> {
        Binding(
            get: { preferences.isDarkMode },
            set: { preferences.setDarkMode($0, auto: false) }
        )
    }

    private var ambientBinding: Binding<String?> {
        Binding(
            get: { viewModel.profile.activeAmbient },
            set: { newValue in
                viewModel.updateProfile { $0.activeAmbient = newValue }
            }
        )
    }

    private var ageBinding: Binding<Int> {
        Binding(
            get: { viewModel.profile.age },
            set: { newValue in
                viewModel.updateProfile { $0.age = newValue }
            }
        )
    }

    private func binding(_ keyPath: WritableKeyPath<SwimProfile, String>) -> Binding<String> {
        Binding(
            get: { viewModel.profile[keyPath: keyPath] },
            set: { newValue in
                viewModel.updateProfile { $0[keyPath: keyPath] = newValue }
            }
        )
    }
}
