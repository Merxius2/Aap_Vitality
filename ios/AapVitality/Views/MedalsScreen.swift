import SwiftUI

struct MedalsScreen: View {
    @EnvironmentObject private var viewModel: SwimViewModel
    @EnvironmentObject private var preferences: UserPreferencesService
    @Environment(\.openUpload) private var openUpload
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var medalGridColumns: [GridItem] {
        horizontalSizeClass == .regular
            ? [GridItem(.flexible()), GridItem(.flexible())]
            : [GridItem(.flexible())]
    }

    var body: some View {
        let medals = viewModel.evaluatedMedals

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(
                        preferences.t("medals.title"),
                        subtitle: preferences.t("medals.subtitle"),
                        pageKey: "medals",
                        systemImage: "medal"
                    )

                    statsCard(medals: medals)

                    if viewModel.sessions.isEmpty {
                        emptyState
                    }

                    MonthlyChallengeHistoryView()

                    ForEach(SwimMedalCopy.categories, id: \.self) { category in
                        categorySection(category, medals: medals)
                    }
                }
                .padding()
            }
            .navigationTitle(preferences.t("medals.title"))
            .navigationBarTitleDisplayMode(.inline)
            .themedNavigationBar()
            .themedPageBackground()
        }
    }

    private func statsCard(medals: [EvaluatedMedal]) -> some View {
        let stats = SwimMedals.getMedalStats(medals)
        return Card {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(preferences.t("medals.subtitle"))
                        .themeFont(.caption)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(stats.earned)")
                            .themeFont(size: 34, weight: .bold)
                        Text("/ \(stats.total)")
                            .themeFont(.title3, weight: .semibold)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(stats.earned > 0 ? "🏆" : "🎯")
                    .font(.system(size: 44))
            }
        }
    }

    private var emptyState: some View {
        Card {
            VStack(spacing: 12) {
                Text(preferences.t("medals.empty"))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button(action: openUpload) {
                    Text(preferences.t("progress.emptyCta"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("BrandBlue"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func categorySection(_ category: String, medals: [EvaluatedMedal]) -> some View {
        let categoryMedals = medals.filter { $0.category == category }
        if !categoryMedals.isEmpty {
            let earnedInCategory = categoryMedals.filter(\.earned).count

            VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(SwimMedalCopy.categoryLabel(category, t: preferences.translations))
                    .themeFont(.caption, weight: .bold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(earnedInCategory)/\(categoryMedals.count)")
                    .themeFont(.caption2)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: medalGridColumns, spacing: 12) {
                ForEach(categoryMedals) { medal in
                    MedalCardView(medal: medal, shimmerPlus: false)
                }
            }
        }
        }
    }
}
