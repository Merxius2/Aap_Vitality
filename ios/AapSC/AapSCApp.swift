import SwiftUI

@main
struct AapSCApp: App {
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

    @State private var showLaunchSessionFlow = false
    @State private var launchFlowPhase: LaunchFlowPhase = .searching
    @State private var launchFeedback: SessionFeedbackSummary?
    @State private var isEnhancingLaunchFeedback = false
    @State private var showMedalCelebration = false

    private var canShowMedalCelebration: Bool {
        showMedalCelebration
            && !showLaunchSessionFlow
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
        .sheet(isPresented: $showLaunchSessionFlow) {
            switch launchFlowPhase {
            case .searching:
                SearchingNewSessionsSheet()
                    .environmentObject(preferences)
                    .preferredColorScheme(preferences.colorScheme)
            case .feedback:
                if let launchFeedback {
                    SessionFeedbackSheet(
                        feedback: launchFeedback,
                        isLoading: isEnhancingLaunchFeedback
                    )
                    .environmentObject(viewModel)
                    .environmentObject(preferences)
                    .preferredColorScheme(preferences.colorScheme)
                }
            }
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
        .onChange(of: showLaunchSessionFlow) { _, isShowing in
            if !isShowing, viewModel.pendingMedalCelebration != nil {
                showMedalCelebration = true
            }
        }
        .task(priority: .utility) {
            try? await Task.sleep(for: .milliseconds(300))
            await performLaunchSessionSearchIfNeeded()
            await viewModel.refreshLaunchNotifications()
        }
        .onAppear {
            ThemeTypography.applyUIKitAppearance(themeCode: preferences.themeCode)
        }
        .onChange(of: preferences.themeCode) { _, themeCode in
            ThemeTypography.applyUIKitAppearance(themeCode: themeCode)
        }
    }

    @MainActor
    private func performLaunchSessionSearchIfNeeded() async {
        guard await viewModel.shouldPerformLaunchSessionSearch() else { return }

        launchFlowPhase = .searching
        showLaunchSessionFlow = true

        async let importedSession = viewModel.performLaunchSessionSearch()
        try? await Task.sleep(for: .milliseconds(900))
        guard let importedSession = await importedSession else {
            showLaunchSessionFlow = false
            return
        }

        var feedback = viewModel.buildSessionFeedback(
            for: importedSession,
            t: preferences.translations
        )
        launchFeedback = feedback
        launchFlowPhase = .feedback

        guard !viewModel.profile.aiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        isEnhancingLaunchFeedback = true
        defer { isEnhancingLaunchFeedback = false }

        if let enhanced = await viewModel.enhanceSessionFeedback(feedback, for: importedSession) {
            feedback = enhanced
            if launchFlowPhase == .feedback {
                launchFeedback = feedback
            }
        }
    }
}

private enum LaunchFlowPhase {
    case searching
    case feedback
}
