import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: VitalityViewModel
    @EnvironmentObject private var preferences: UserPreferencesService
    @Environment(\.appIsDark) private var appIsDark
    @State private var selectedTab = 0
    @State private var showUpload = false

    private var appearanceKey: String {
        "\(preferences.themeCode)-\(appIsDark)-\(preferences.isAutoDarkMode)-\(preferences.isDarkMode)"
    }

    var body: some View {
        tabContent
            .id(appearanceKey)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                CustomTabBar(
                    selectedTab: $selectedTab,
                    progressActive: selectedTab == 0,
                    onProgress: { selectedTab = 0 },
                    settingsTitle: preferences.t("navigation.settings"),
                    medalsTitle: preferences.t("navigation.medals"),
                    progressTitle: preferences.t("navigation.progress"),
                    benchmarkTitle: preferences.t("navigation.goals"),
                    historyTitle: preferences.t("navigation.history")
                )
                .id(appearanceKey)
                .ignoresSafeArea(.container, edges: .bottom)
            }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showUpload) {
            UploadScreen()
                .preferredColorScheme(preferences.colorScheme)
        }
        .environment(\.openUpload, { showUpload = true })
        .environment(\.openSettingsTab, { selectedTab = 2 })
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0:
            ProgressScreen()
        case 1:
            MedalsScreen()
        case 2:
            SettingsScreen(embedded: true)
        case 3:
            VitalityGoalsScreen()
        case 4:
            HistoryScreen()
        default:
            ProgressScreen()
        }
    }
}

private struct OpenUploadKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

private struct OpenSettingsTabKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var openUpload: () -> Void {
        get { self[OpenUploadKey.self] }
        set { self[OpenUploadKey.self] = newValue }
    }

    var openSettingsTab: () -> Void {
        get { self[OpenSettingsTabKey.self] }
        set { self[OpenSettingsTabKey.self] = newValue }
    }
}

struct Card<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard()
    }
}
