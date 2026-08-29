import SwiftUI

@main
struct AapVitalityApp: App {
    @StateObject private var viewModel = SwimViewModel()
    @StateObject private var preferences = UserPreferencesService()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(viewModel)
                .environmentObject(preferences)
        }
    }
}

private struct AppRootView: View {
    @EnvironmentObject private var viewModel: SwimViewModel
    @EnvironmentObject private var preferences: UserPreferencesService
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.scenePhase) private var scenePhase

    @State private var showLaunchSync = false
    @State private var showMedalCelebration = false

    private var canShowMedalCelebration: Bool {
        showMedalCelebration
            && !showLaunchSync
            && viewModel.pendingMedalCelebration != nil
    }

    private var appIsDark: Bool {
        preferences.isDarkModeActive(systemColorScheme: systemColorScheme)
    }

    private var animationsPaused: Bool {
        scenePhase != .active
    }

    private var ambientBackgroundVisible: Bool {
        BackdropState.isCustomVisible(
            activeWallpaper: viewModel.profile.activeWallpaper,
            activeAmbient: viewModel.profile.activeAmbient
        )
    }

    var body: some View {
        ContentView()
            .environment(\.t, preferences.translations)
            .environment(\.themeColors, preferences.themeColors)
            .environment(\.appIsDark, appIsDark)
            .environment(\.ambientBackgroundVisible, ambientBackgroundVisible)
            .environment(\.appAnimationsPaused, animationsPaused)
            .environment(\.themeTypographyCode, preferences.themeCode)
            .tint(preferences.themeColors.displayPrimary)
            .preferredColorScheme(preferences.colorScheme)
            .themedBodyFont()
        .sheet(isPresented: $showLaunchSync) {
            SearchingNewSessionsSheet()
                .environmentObject(preferences)
                .preferredColorScheme(preferences.colorScheme)
        }
        .sheet(isPresented: Binding(
            get: { canShowMedalCelebration },
            set: { isPresented in
                if !isPresented {
                    showMedalCelebration = false
                    viewModel.clearMedalCelebration()
                }
            }
        )) {
            if let medals = viewModel.pendingMedalCelebration {
                MedalCelebrationSheet(medals: medals)
                    .environmentObject(preferences)
                    .preferredColorScheme(preferences.colorScheme)
            }
        }
        .onChange(of: viewModel.pendingMedalCelebration) { _, medals in
            if let medals, !medals.isEmpty {
                showMedalCelebration = true
            }
        }
        .onChange(of: showLaunchSync) { _, isShowing in
            if !isShowing, viewModel.pendingMedalCelebration != nil {
                showMedalCelebration = true
            }
        }
        .task(priority: .utility) {
            try? await Task.sleep(for: .milliseconds(300))
            await performLaunchVitalitySyncIfNeeded()
            await viewModel.refreshNotifications(
                dailyGoalNotificationsEnabled: preferences.dailyGoalNotificationsEnabled
            )
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await viewModel.refreshNotifications(
                    dailyGoalNotificationsEnabled: preferences.dailyGoalNotificationsEnabled
                )
            }
        }
        .onChange(of: preferences.dailyGoalNotificationsEnabled) { _, enabled in
            Task {
                await viewModel.refreshNotifications(dailyGoalNotificationsEnabled: enabled)
            }
        }
        .onAppear {
            ThemeTypography.applyUIKitAppearance(themeCode: preferences.themeCode)
        }
        .onChange(of: preferences.themeCode) { _, themeCode in
            ThemeTypography.applyUIKitAppearance(themeCode: themeCode)
        }
    }

    @MainActor
    private func performLaunchVitalitySyncIfNeeded() async {
        guard await viewModel.shouldPerformLaunchVitalitySync() else { return }

        showLaunchSync = true
        async let importedCount = viewModel.performLaunchVitalitySync()
        try? await Task.sleep(for: .milliseconds(900))
        _ = await importedCount
        showLaunchSync = false
    }
}
