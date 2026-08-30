import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: VitalityViewModel
    @EnvironmentObject private var preferences: UserPreferencesService
    @Environment(\.appIsDark) private var appIsDark
    @State private var selectedTab = 0
    @State private var loadedTabs: Set<Int> = [0]
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
        let mounted = loadedTabs.union([selectedTab])
        ZStack {
            if mounted.contains(0) {
                persistedTab(0) { ProgressScreen() }
            }
            if mounted.contains(1) {
                persistedTab(1) { MedalsScreen() }
            }
            if mounted.contains(2) {
                persistedTab(2) { SettingsScreen(embedded: true) }
            }
            if mounted.contains(3) {
                persistedTab(3) { VitalityGoalsScreen() }
            }
            if mounted.contains(4) {
                persistedTab(4) { HistoryScreen() }
            }
        }
        .onChange(of: selectedTab) { _, tab in
            loadedTabs.insert(tab)
        }
        .onAppear {
            Task { @MainActor in
                await Task.yield()
                viewModel.warmDerivedCaches()
            }
        }
    }

    private func persistedTab<Content: View>(
        _ tab: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isActive = selectedTab == tab
        return content()
            .opacity(isActive ? 1 : 0)
            .animation(nil, value: isActive)
            .allowsHitTesting(isActive)
            .accessibilityHidden(!isActive)
            .zIndex(isActive ? 1 : 0)
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
