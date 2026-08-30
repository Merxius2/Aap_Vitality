import SwiftUI

struct MilestoneProgressBar: View {
    let value: Int
    let title: String
    let milestones: [Int]
    let milestonePoints: [Int]
    let colors: [Color]
    let markerText: String
    let milestoneLabel: (Int) -> String
    let pointsLabel: (Int) -> String
    let accessibilityNoun: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .themeFont(.caption, weight: .bold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            GeometryReader { geometry in
                let barWidth = geometry.size.width
                let markerX = barWidth * visualProgress(for: value)

                VStack(spacing: 6) {
                    ZStack(alignment: .leading) {
                        HStack(spacing: 3) {
                            ForEach(Array(milestones.enumerated()), id: \.offset) { index, milestone in
                                segmentBar(
                                    index: index,
                                    milestone: milestone,
                                    color: color(at: index)
                                )
                            }
                        }
                        .frame(height: 28)

                        marker
                            .position(
                                x: min(max(markerX, 32), max(barWidth - 32, 32)),
                                y: 14
                            )
                    }
                    .frame(height: 28)

                    HStack(spacing: 3) {
                        ForEach(Array(milestones.enumerated()), id: \.offset) { index, milestone in
                            milestoneLabelBlock(
                                index: index,
                                milestone: milestone,
                                color: color(at: index)
                            )
                        }
                    }
                }
            }
            .frame(height: 58)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private func color(at index: Int) -> Color {
        colors[min(index, max(colors.count - 1, 0))]
    }

    private func segmentBar(index: Int, milestone: Int, color: Color) -> some View {
        let start = index == 0 ? 0 : milestones[index - 1]
        let reached = value >= milestone
        let fill = segmentFill(value: value, start: start, end: milestone, reached: reached)

        return GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(color.opacity(reached ? 0.28 : 0.12))

                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(reached ? color : color.opacity(0.9))
                        .frame(width: geometry.size.width * fill)
                    Spacer(minLength: 0)
                }

                if reached {
                    Image(systemName: "checkmark.circle.fill")
                        .themeFont(.caption, weight: .bold)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func milestoneLabelBlock(index: Int, milestone: Int, color: Color) -> some View {
        let reached = value >= milestone
        let points = milestonePoints.indices.contains(index) ? milestonePoints[index] : 0
        let extra = pointsLabel(points)

        return VStack(spacing: 2) {
            HStack(spacing: 4) {
                if reached {
                    Image(systemName: "checkmark")
                        .themeFont(.caption2, weight: .bold)
                }
                Text(milestoneLabel(milestone))
                    .themeFont(.caption2, weight: .semibold)
            }
            .foregroundStyle(reached ? color : .secondary)

            if !extra.isEmpty {
                Text(extra)
                    .themeFont(.caption2)
                    .foregroundStyle(reached ? color.opacity(0.9) : .secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var marker: some View {
        Text(markerText)
            .themeFont(.caption2, weight: .bold)
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.82), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
    }

    private func segmentFill(value: Int, start: Int, end: Int, reached: Bool) -> CGFloat {
        guard !reached else { return 1 }
        guard value > start, end > start else { return 0 }
        return CGFloat(value - start) / CGFloat(end - start)
    }

    private func visualProgress(for value: Int) -> CGFloat {
        guard !milestones.isEmpty else { return 0 }
        let segmentWeight = 1.0 / CGFloat(milestones.count)
        var progress: CGFloat = 0

        for (index, milestone) in milestones.enumerated() {
            let start = index == 0 ? 0 : milestones[index - 1]
            if value >= milestone {
                progress += segmentWeight
            } else if value > start, milestone > start {
                progress += segmentWeight * CGFloat(value - start) / CGFloat(milestone - start)
                break
            } else {
                break
            }
        }

        return min(max(progress, value > 0 ? 0.04 : 0), 1)
    }

    private var accessibilitySummary: String {
        let reached = milestones.filter { value >= $0 }.map(milestoneLabel)
        if reached.isEmpty {
            return "\(title). \(markerText) \(accessibilityNoun)."
        }
        return "\(title). \(markerText) \(accessibilityNoun). Reached: \(reached.joined(separator: ", "))."
    }
}

struct StepMilestoneProgressBar: View {
    let steps: Int
    let title: String
    let milestoneLabel: (Int) -> String
    let pointsLabel: (Int) -> String

    var body: some View {
        MilestoneProgressBar(
            value: steps,
            title: title,
            milestones: VitalityPoints.stepMilestones,
            milestonePoints: VitalityPoints.stepMilestonePoints,
            colors: [.teal, .green, Color("BrandBlue")],
            markerText: steps.formatted(.number.grouping(.automatic)),
            milestoneLabel: milestoneLabel,
            pointsLabel: pointsLabel,
            accessibilityNoun: "steps"
        )
    }
}

struct SleepMilestoneProgressBar: View {
    let minutes: Int
    let title: String
    let hoursLabel: (Int) -> String
    let pointsLabel: (Int) -> String
    let durationText: String

    var body: some View {
        MilestoneProgressBar(
            value: minutes,
            title: title,
            milestones: VitalityPoints.sleepMilestonesMinutes,
            milestonePoints: VitalityPoints.sleepMilestonePoints,
            colors: [.purple, .indigo],
            markerText: durationText,
            milestoneLabel: { minutes in hoursLabel(minutes / 60) },
            pointsLabel: pointsLabel,
            accessibilityNoun: "sleep"
        )
    }
}

struct DailyPointsProgressBar: View {
    let points: Int
    let dailyTarget: Int
    let title: String
    let halfwayLabel: String
    let goalLabel: String
    let stretchLabel: String

    private var milestones: [Int] {
        let goal = max(dailyTarget, 1)
        let halfway = max(goal / 2, 1)
        let stretch = max(Int((Double(goal) * 1.5).rounded()), goal + 1)
        return [halfway, goal, stretch]
    }

    var body: some View {
        MilestoneProgressBar(
            value: points,
            title: title,
            milestones: milestones,
            milestonePoints: milestones,
            colors: [.orange, Color("BrandBlue"), .green],
            markerText: "\(points)",
            milestoneLabel: { milestone in
                if milestone == milestones[0] { return halfwayLabel }
                if milestone == milestones[1] { return goalLabel }
                return stretchLabel
            },
            pointsLabel: { value in
                "\(value)"
            },
            accessibilityNoun: "points"
        )
    }
}
