import SwiftUI

struct StepMilestoneProgressBar: View {
    let steps: Int
    let title: String
    let milestoneLabel: (Int) -> String
    let pointsLabel: (Int) -> String

    private let milestones = VitalityPoints.stepMilestones
    private let milestonePoints = VitalityPoints.stepMilestonePoints
    private let segmentColors: [Color] = [.teal, .green, Color("BrandBlue")]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .themeFont(.caption, weight: .bold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            GeometryReader { geometry in
                let barWidth = geometry.size.width
                let markerX = barWidth * visualProgress(for: steps)

                VStack(spacing: 6) {
                    ZStack(alignment: .leading) {
                        HStack(spacing: 3) {
                            ForEach(Array(milestones.enumerated()), id: \.offset) { index, milestone in
                                segmentBar(
                                    index: index,
                                    milestone: milestone,
                                    color: segmentColors[min(index, segmentColors.count - 1)]
                                )
                            }
                        }
                        .frame(height: 28)

                        stepCountMarker
                            .position(
                                x: min(max(markerX, 28), max(barWidth - 28, 28)),
                                y: 14
                            )
                    }
                    .frame(height: 28)

                    HStack(spacing: 3) {
                        ForEach(Array(milestones.enumerated()), id: \.offset) { index, milestone in
                            milestoneLabelBlock(
                                index: index,
                                milestone: milestone,
                                color: segmentColors[min(index, segmentColors.count - 1)]
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

    private func segmentBar(index: Int, milestone: Int, color: Color) -> some View {
        let start = index == 0 ? 0 : milestones[index - 1]
        let reached = steps >= milestone
        let fill = segmentFill(steps: steps, start: start, end: milestone, reached: reached)

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
        let reached = steps >= milestone
        let points = milestonePoints[index]

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

            Text(pointsLabel(points))
                .themeFont(.caption2)
                .foregroundStyle(reached ? color.opacity(0.9) : .secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var stepCountMarker: some View {
        Text(formattedSteps)
            .themeFont(.caption2, weight: .bold)
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.82), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
    }

    private var formattedSteps: String {
        steps.formatted(.number.grouping(.automatic))
    }

    private func segmentFill(steps: Int, start: Int, end: Int, reached: Bool) -> CGFloat {
        guard !reached else { return 1 }
        guard steps > start else { return 0 }
        return CGFloat(steps - start) / CGFloat(end - start)
    }

    /// Maps step count to bar position across equal-width milestone segments.
    private func visualProgress(for steps: Int) -> CGFloat {
        guard !milestones.isEmpty else { return 0 }
        let segmentWeight = 1.0 / CGFloat(milestones.count)
        var progress: CGFloat = 0

        for (index, milestone) in milestones.enumerated() {
            let start = index == 0 ? 0 : milestones[index - 1]
            if steps >= milestone {
                progress += segmentWeight
            } else if steps > start {
                progress += segmentWeight * CGFloat(steps - start) / CGFloat(milestone - start)
                break
            } else {
                break
            }
        }

        return min(max(progress, steps > 0 ? 0.04 : 0), 1)
    }

    private var accessibilitySummary: String {
        let reached = milestones.filter { steps >= $0 }.map(milestoneLabel)
        if reached.isEmpty {
            return "\(title). \(formattedSteps) steps."
        }
        return "\(title). \(formattedSteps) steps. Reached: \(reached.joined(separator: ", "))."
    }
}
