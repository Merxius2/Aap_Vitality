import SwiftUI

struct MedalsScreen: View {
    @EnvironmentObject private var viewModel: VitalityViewModel
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
                    statsCard(medals: medals)

                    if !viewModel.dailyRecords.isEmpty {
                        achievementPathsSection
                    }

                    if viewModel.dailyRecords.isEmpty {
                        emptyState
                    }

                    MonthlyChallengeHistoryView()

                    ForEach(SwimMedalCopy.categories, id: \.self) { category in
                        categorySection(category, medals: medals)
                    }
                }
                .padding()
            }
            .toolbar(.hidden, for: .navigationBar)
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

    private var achievementPathsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(preferences.t("vitality.paths.title"))
                .themeFont(.caption, weight: .bold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(viewModel.achievementPathProgress) { path in
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(preferences.t(path.titleKey))
                                .themeFont(.subheadline, weight: .semibold)
                            Spacer()
                            Text("\(path.completedCount)/\(path.totalCount)")
                                .themeFont(.caption, weight: .bold)
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(value: Double(path.progressPercent), total: 100)
                            .tint(Color("BrandBlue"))
                        if let nextId = path.nextMedalId {
                            Text(preferences.t("vitality.paths.next", params: [
                                "medal": SwimMedalCopy.title(for: nextId, t: preferences.translations)
                            ]))
                            .themeFont(.caption2)
                            .foregroundStyle(.secondary)
                        } else {
                            Text(preferences.t("vitality.paths.complete"))
                                .themeFont(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
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
