import Foundation

enum SwimFeedback {
    private struct DominantStroke {
        let key: String
        let meters: Int
        let share: Double
    }

    private struct PersonalBests {
        var fastestPace: Int?
        var longestDistance: Int?
        var mostLaps: Int?
    }

    private struct FeedbackContext {
        let newSession: SwimSession
        let allSessions: [SwimSession]
        let metrics: SwimMetrics
        let sessionCount: Int
        let isFirst: Bool
        let previous: SwimSession?
        let recentPrior: [SwimSession]
        let recentAvgPace: Double?
        let recentAvgDistance: Double?
        let combinedAvgPace: Int?
        let daysSinceLast: Int?
        let monthDistance: Int
        let prevMonthDistance: Int
        let benchmark: BenchmarkTier?
        let benchmarkLevel: SwimLevel
        let percentile: Int?
        let dominantStroke: DominantStroke?
        let weeklyVolume: Int
        let paceTrendDelta: Double?
        let paceDeltaVsRecent: Double?
        let paceDeltaVsPrevious: Double?
        let hasPb: Bool
        let combined: CombinedStats?
    }

    private static let strokeKeys = ["mixedM", "breaststrokeM", "freestyleM", "backstrokeM", "butterflyM"]
    private static let strokeI18n: [String: String] = [
        "mixedM": "strokes.mixed",
        "breaststrokeM": "strokes.breaststroke",
        "freestyleM": "strokes.freestyle",
        "backstrokeM": "strokes.backstroke",
        "butterflyM": "strokes.butterfly",
    ]

    static func buildPersonalFeedback(
        session: SwimSession,
        allSessions: [SwimSession],
        profile: SwimProfile,
        t: TranslationService,
        monthlyChallengeRerolls: [String: MonthRerollEntry] = [:]
    ) -> SessionFeedbackSummary {
        let sessionsForStats = sessionsForStats(allSessions, newSession: session)
        let base = analyzeSession(newSession: session, allSessions: sessionsForStats, t: t)
        let combined = SwimAnalysis.combinedStats(sessionsForStats)
        let ctx = gatherFeedbackContext(
            newSession: session,
            allSessions: sessionsForStats,
            profile: profile,
            base: base,
            combined: combined
        )
        let insights = enrichInsights(base: base, ctx: ctx, t: t)

        let mascotContext = sessionsForStats
        let mascotId = MascotUnlock.resolveMascotId(
            profile: profile,
            sessions: mascotContext,
            monthlyChallengeRerolls: monthlyChallengeRerolls
        )
        let coachGameplay = MascotConstants.gameplay(mascotId)

        var usedPaceDownMotivation = false
        let motivation: String
        if ctx.isFirst {
            motivation = t.t("feedback.motivationFirst")
        } else if ctx.hasPb {
            motivation = t.t("feedback.motivationPersonalBest")
        } else if let delta = ctx.paceDeltaVsPrevious, delta >= 5 {
            motivation = t.t("feedback.motivationPaceUp", params: ["seconds": String(Int(delta.rounded()))])
        } else if let delta = ctx.paceDeltaVsPrevious, delta <= -5 {
            if coachGameplay.positiveOnly {
                motivation = FeedbackVariants.translateVariant(
                    t,
                    baseKey: "feedback.motivationKeepGoing",
                    count: 3,
                    seed: session.date
                )
            } else if coachGameplay.sessionPenalty {
                motivation = t.t("feedback.motivationPaceDownCritical")
                usedPaceDownMotivation = true
            } else {
                motivation = t.t("feedback.motivationPaceDown")
                usedPaceDownMotivation = true
            }
        } else if let goal = ctx.metrics.goalM, let distance = ctx.metrics.distanceM, distance >= goal {
            motivation = t.t("feedback.motivationGoal")
        } else if let trend = ctx.paceTrendDelta, trend >= 4 {
            motivation = t.t("feedback.motivationTrendUp")
        } else if recentCount(ctx: ctx, days: 7) >= 3 {
            motivation = FeedbackVariants.translateVariant(
                t,
                baseKey: "feedback.motivationConsistent",
                count: 2,
                seed: session.date
            )
        } else {
            motivation = FeedbackVariants.translateVariant(
                t,
                baseKey: "feedback.motivationKeepGoing",
                count: 3,
                seed: "\(session.date)-default"
            )
        }

        var coachMessage = buildCoachNarrative(ctx: ctx, t: t, coachGameplay: coachGameplay)
        coachMessage = SwimAnalysis.wrapCoachMessage(
            mascotId: mascotId,
            profile: profile,
            t: t,
            message: coachMessage
        )
        if profile.age > 0 && !ctx.isFirst {
            coachMessage += " \(t.t("feedback.ageNote", params: ["age": String(profile.age)]))"
        }

        let visibleInsights = coachGameplay.positiveOnly
            ? insights.filter(isPositiveInsight)
            : insights

        let usedCriticalCoachLine = wasCriticalCoachLine(ctx: ctx, coachGameplay: coachGameplay)
        let mascotMood = resolveSessionMascotMood(
            mascotId: mascotId,
            isFirst: ctx.isFirst,
            hasPb: ctx.hasPb,
            paceDeltaVsPrevious: ctx.paceDeltaVsPrevious,
            usedCriticalCoachLine: usedCriticalCoachLine,
            usedPaceDownMotivation: usedPaceDownMotivation
        )

        return SessionFeedbackSummary(
            insights: visibleInsights,
            badges: base.badges,
            coachMessage: coachMessage.trimmingCharacters(in: .whitespacesAndNewlines),
            motivation: motivation,
            benchmarkLevel: ctx.benchmarkLevel,
            highlights: buildHighlights(ctx: ctx, t: t),
            tip: buildCoachingTip(ctx: ctx, t: t),
            mascotMood: mascotMood
        )
    }

    private struct AnalyzeBase {
        var insights: [String]
        var badges: [String]
        var weeklyVolume: Int
    }

    private static func analyzeSession(
        newSession: SwimSession,
        allSessions: [SwimSession],
        t: TranslationService
    ) -> AnalyzeBase {
        var insights: [String] = []
        var badges: [String] = []
        let metrics = newSession.metrics
        let previous = previousSession(allSessions, currentId: newSession.id)
        let bests = personalBests(allSessions, excludeId: newSession.id)

        if let prevPace = previous?.metrics.paceSecPer100m,
           let pace = metrics.paceSecPer100m {
            let delta = prevPace - pace
            if delta > 0 {
                insights.append(t.t("feedback.paceFaster", params: ["seconds": String(delta)]))
            } else if delta < 0 {
                insights.append(t.t("feedback.paceSlower", params: ["seconds": String(abs(delta))]))
            } else {
                insights.append(t.t("feedback.paceSame"))
            }
        }

        if let goal = metrics.goalM, let distance = metrics.distanceM {
            let diff = distance - goal
            if diff > 0 {
                insights.append(t.t("feedback.overGoal", params: ["meters": String(diff)]))
            } else if diff < 0 {
                insights.append(t.t("feedback.underGoal", params: ["meters": String(abs(diff))]))
            } else {
                insights.append(t.t("feedback.hitGoal"))
            }
        }

        if let prevHR = previous?.metrics.avgHeartRate,
           let hr = metrics.avgHeartRate {
            let delta = hr - prevHR
            if delta > 0 {
                insights.append(t.t("feedback.hrHigher", params: ["bpm": String(delta)]))
            } else if delta < 0 {
                insights.append(t.t("feedback.hrLower", params: ["bpm": String(abs(delta))]))
            }
        }

        if let pace = metrics.paceSecPer100m,
           let fastest = bests.fastestPace,
           pace <= fastest {
            badges.append(t.t("feedback.pbPace"))
        }
        if let distance = metrics.distanceM,
           let longest = bests.longestDistance,
           distance >= longest {
            badges.append(t.t("feedback.pbDistance"))
        }
        if let laps = metrics.laps,
           let most = bests.mostLaps,
           laps >= most {
            badges.append(t.t("feedback.pbLaps"))
        }

        let weeklyVolume = weeklyVolume(allSessions, referenceDate: newSession.date)
        if weeklyVolume > 0 {
            insights.append(t.t("feedback.weeklyVolume", params: [
                "distance": SwimFormatters.formatDistance(weeklyVolume)
            ]))
        }

        if let prevStrokes = previous?.metrics.strokes {
            let prevBreast = prevStrokes.breaststrokeM ?? 0
            let currBreast = metrics.strokes.breaststrokeM ?? 0
            if currBreast > prevBreast + 100 {
                insights.append(t.t("feedback.moreBreaststroke"))
            }
        }

        return AnalyzeBase(insights: insights, badges: badges, weeklyVolume: weeklyVolume)
    }

    private static func gatherFeedbackContext(
        newSession: SwimSession,
        allSessions: [SwimSession],
        profile: SwimProfile,
        base: AnalyzeBase,
        combined: CombinedStats?
    ) -> FeedbackContext {
        let metrics = newSession.metrics
        let sorted = SwimAnalysis.sortedSessions(allSessions)
        let isFirst = sorted.count == 1
        let previous = previousSession(allSessions, currentId: newSession.id)
        let recentPrior = recentPriorSessions(allSessions, currentId: newSession.id, limit: 5)
        let recentPaces = recentPrior.compactMap(\.metrics.paceSecPer100m).map(Double.init)
        let recentDistances = recentPrior.compactMap(\.metrics.distanceM).map(Double.init)
        let recentAvgPace = average(recentPaces)
        let recentAvgDistance = average(recentDistances)
        let combinedAvgPace = combined?.avgPaceSecPer100m
        let daysSinceLast = daysSincePrevious(allSessions, currentId: newSession.id, currentDate: newSession.date)
        let monthKey = String(newSession.date.prefix(7))
        let currentMonthDistance = monthDistance(allSessions, monthKey: monthKey)
        let prevMonthDistance = monthDistance(allSessions, monthKey: shiftMonthKey(monthKey, by: -1))

        let benchmark = profile.sex.isEmpty || profile.age <= 0
            ? nil
            : SwimBenchmarks.benchmark(for: profile.sex, age: profile.age)
        let benchmarkLevel = benchmark.map {
            SwimBenchmarks.swimLevel(paceSecPer100m: metrics.paceSecPer100m, benchmark: $0)
        } ?? .unknown
        let percentile = benchmark.flatMap { tier in
            metrics.paceSecPer100m.map {
                SwimBenchmarks.computePacePercentile(paceSecPer100m: $0, benchmark: tier)
            }
        }
        let dominantStroke = dominantStroke(metrics.strokes)
        let weeklyVolume = base.weeklyVolume

        var paceTrendDelta: Double?
        if recentPaces.count >= 3 {
            let split = recentPaces.count / 2
            let older = average(Array(recentPaces.prefix(split)))
            let newer = average(Array(recentPaces.suffix(recentPaces.count - split)))
            if let older, let newer {
                paceTrendDelta = older - newer
            }
        }

        let paceDeltaVsRecent: Double?
        if let recentAvgPace, let pace = metrics.paceSecPer100m {
            paceDeltaVsRecent = recentAvgPace - Double(pace)
        } else {
            paceDeltaVsRecent = nil
        }

        let paceDeltaVsPrevious: Double?
        if let prevPace = previous?.metrics.paceSecPer100m, let pace = metrics.paceSecPer100m {
            paceDeltaVsPrevious = Double(prevPace - pace)
        } else {
            paceDeltaVsPrevious = nil
        }

        return FeedbackContext(
            newSession: newSession,
            allSessions: allSessions,
            metrics: metrics,
            sessionCount: sorted.count,
            isFirst: isFirst,
            previous: previous,
            recentPrior: recentPrior,
            recentAvgPace: recentAvgPace,
            recentAvgDistance: recentAvgDistance,
            combinedAvgPace: combinedAvgPace,
            daysSinceLast: daysSinceLast,
            monthDistance: currentMonthDistance,
            prevMonthDistance: prevMonthDistance,
            benchmark: benchmark,
            benchmarkLevel: benchmarkLevel,
            percentile: percentile,
            dominantStroke: dominantStroke,
            weeklyVolume: weeklyVolume,
            paceTrendDelta: paceTrendDelta,
            paceDeltaVsRecent: paceDeltaVsRecent,
            paceDeltaVsPrevious: paceDeltaVsPrevious,
            hasPb: !base.badges.isEmpty,
            combined: combined
        )
    }

    private static func enrichInsights(base: AnalyzeBase, ctx: FeedbackContext, t: TranslationService) -> [String] {
        var insights = base.insights

        if !ctx.isFirst && recentCount(ctx: ctx, days: 7) >= 3 {
            insights.insert(t.t("feedback.streak", params: ["count": String(recentCount(ctx: ctx, days: 7))]), at: 0)
        }

        if let recentAvgPace = ctx.recentAvgPace, let pace = ctx.metrics.paceSecPer100m {
            let delta = Int((recentAvgPace - Double(pace)).rounded())
            if delta >= 3 {
                insights.append(t.t("feedback.vsRecentAvgFaster", params: ["seconds": String(delta)]))
            } else if delta <= -3 {
                insights.append(t.t("feedback.vsRecentAvgSlower", params: ["seconds": String(abs(delta))]))
            }
        }

        if let combinedAvgPace = ctx.combinedAvgPace,
           let pace = ctx.metrics.paceSecPer100m,
           ctx.sessionCount >= 4 {
            let delta = combinedAvgPace - pace
            if abs(delta) >= 3 {
                insights.append(
                    delta > 0
                        ? t.t("feedback.vsAllTimeAvgFaster", params: ["seconds": String(delta)])
                        : t.t("feedback.vsAllTimeAvgSlower", params: ["seconds": String(abs(delta))])
                )
            }
        }

        if let recentAvgDistance = ctx.recentAvgDistance, let distance = ctx.metrics.distanceM {
            let diff = Double(distance) - recentAvgDistance
            if diff >= 200 {
                insights.append(t.t("feedback.longerThanRecent", params: [
                    "distance": SwimFormatters.formatDistance(Int(diff.rounded()))
                ]))
            } else if diff <= -200 {
                insights.append(t.t("feedback.shorterThanRecent", params: [
                    "distance": SwimFormatters.formatDistance(Int(abs(diff).rounded()))
                ]))
            }
        }

        if let days = ctx.daysSinceLast, days > 1 {
            insights.append(t.t("feedback.daysSinceLast", params: ["days": String(days)]))
        }

        if ctx.benchmark != nil, ctx.metrics.paceSecPer100m != nil, ctx.benchmarkLevel != .unknown {
            insights.append(t.t("feedback.benchmarkLevel", params: [
                "level": t.t("benchmark.levels.\(ctx.benchmarkLevel.rawValue)")
            ]))
            if let benchmark = ctx.benchmark, let pace = ctx.metrics.paceSecPer100m {
                let medianDelta = pace - benchmark.median
                if medianDelta < 0 {
                    insights.append(t.t("feedback.vsMedianFaster", params: ["seconds": String(abs(medianDelta))]))
                } else if medianDelta > 0 {
                    insights.append(t.t("feedback.vsMedianSlower", params: ["seconds": String(medianDelta)]))
                }
            }
        }

        if ctx.monthDistance > 0 {
            if ctx.prevMonthDistance > 0 {
                let change = Int((Double(ctx.monthDistance - ctx.prevMonthDistance) / Double(ctx.prevMonthDistance) * 100).rounded())
                insights.append(t.t("feedback.monthlyCompare", params: [
                    "distance": SwimFormatters.formatDistance(ctx.monthDistance),
                    "change": change >= 0 ? "+\(change)" : String(change)
                ]))
            } else {
                insights.append(t.t("feedback.monthlyDistance", params: [
                    "distance": SwimFormatters.formatDistance(ctx.monthDistance)
                ]))
            }
        }

        if let kcal = ctx.metrics.activeKcal, kcal >= 200 {
            insights.append(t.t("feedback.caloriesBurned", params: ["kcal": String(kcal)]))
        }

        if let duration = ctx.metrics.durationSec,
           let distance = ctx.metrics.distanceM,
           distance > 0 {
            let metersPerMin = (Double(distance) / Double(duration)) * 60
            if metersPerMin >= 40 {
                insights.append(t.t("feedback.sustainedEffort", params: ["rate": String(Int(metersPerMin.rounded()))]))
            }
        }

        if let dominant = ctx.dominantStroke, dominant.share >= 0.55 {
            let strokeKey = strokeI18n[dominant.key] ?? "strokes.mixed"
            insights.append(t.t("feedback.dominantStroke", params: [
                "stroke": t.t(strokeKey),
                "percent": String(Int((dominant.share * 100).rounded()))
            ]))
        }

        if let trend = ctx.paceTrendDelta, ctx.recentPrior.count >= 3 {
            if trend >= 4 {
                insights.append(t.t("feedback.trendImproving", params: ["sessions": String(ctx.recentPrior.count)]))
            } else if trend <= -4 {
                insights.append(t.t("feedback.trendSlowing", params: ["sessions": String(ctx.recentPrior.count)]))
            }
        }

        if let combined = ctx.combined, combined.sessionCount >= 2 {
            insights.append(t.t("feedback.allTimeDistance", params: [
                "distance": SwimFormatters.formatDistance(combined.totalDistanceM),
                "count": String(combined.sessionCount)
            ]))
        }

        return Array(Set(insights))
    }

    private static func buildHighlights(ctx: FeedbackContext, t: TranslationService) -> [FeedbackHighlight] {
        var highlights: [FeedbackHighlight] = []

        if let pace = ctx.metrics.paceSecPer100m {
            highlights.append(FeedbackHighlight(
                label: t.t("feedback.highlightPace"),
                value: SwimFormatters.formatPace(pace)
            ))
        }
        if let distance = ctx.metrics.distanceM {
            highlights.append(FeedbackHighlight(
                label: t.t("feedback.highlightDistance"),
                value: SwimFormatters.formatDistance(distance)
            ))
        }
        if ctx.benchmarkLevel != .unknown {
            highlights.append(FeedbackHighlight(
                label: t.t("feedback.highlightLevel"),
                value: t.t("benchmark.levels.\(ctx.benchmarkLevel.rawValue)")
            ))
        }
        if ctx.weeklyVolume > 0 {
            highlights.append(FeedbackHighlight(
                label: t.t("feedback.highlightWeek"),
                value: SwimFormatters.formatDistance(ctx.weeklyVolume)
            ))
        }
        if let percentile = ctx.percentile, ctx.metrics.paceSecPer100m != nil {
            highlights.append(FeedbackHighlight(
                label: t.t("feedback.highlightPercentile"),
                value: t.t("feedback.percentileValue", params: ["percentile": String(percentile)])
            ))
        } else if let recentAvgPace = ctx.recentAvgPace, let pace = ctx.metrics.paceSecPer100m {
            let delta = Int((recentAvgPace - Double(pace)).rounded())
            if delta != 0 {
                highlights.append(FeedbackHighlight(
                    label: t.t("feedback.highlightVsRecent"),
                    value: delta > 0
                        ? t.t("feedback.vsRecentFasterShort", params: ["seconds": String(delta)])
                        : t.t("feedback.vsRecentSlowerShort", params: ["seconds": String(abs(delta))])
                ))
            }
        }

        return Array(highlights.prefix(4))
    }

    private static func buildCoachingTip(ctx: FeedbackContext, t: TranslationService) -> String {
        if ctx.isFirst { return t.t("feedback.tipFirst") }

        if let days = ctx.daysSinceLast, days >= 10 {
            return t.t("feedback.tipConsistency", params: ["days": String(days)])
        }

        if let prev = ctx.previous,
           let prevPace = prev.metrics.paceSecPer100m,
           let pace = ctx.metrics.paceSecPer100m,
           let hr = ctx.metrics.avgHeartRate,
           let prevHR = prev.metrics.avgHeartRate,
           pace > prevPace + 4,
           hr >= prevHR + 5 {
            return t.t("feedback.tipRecovery")
        }

        if ctx.benchmarkLevel == .developing {
            return t.t("feedback.tipDeveloping")
        }

        if let dominant = ctx.dominantStroke, dominant.share >= 0.8 {
            let strokeKey = strokeI18n[dominant.key] ?? "strokes.mixed"
            return t.t("feedback.tipStrokeVariety", params: [
                "stroke": t.t(strokeKey),
                "percent": String(Int((dominant.share * 100).rounded()))
            ])
        }

        if let recentAvgDistance = ctx.recentAvgDistance,
           let distance = ctx.metrics.distanceM,
           let pace = ctx.metrics.paceSecPer100m,
           let recentAvgPace = ctx.recentAvgPace,
           Double(distance) < recentAvgDistance * 0.75,
           Double(pace) <= recentAvgPace - 3 {
            return t.t("feedback.tipBuildDistance")
        }

        if let trend = ctx.paceTrendDelta, trend <= -4 {
            return t.t("feedback.tipSlowingTrend")
        }

        if let trend = ctx.paceTrendDelta, trend >= 4 {
            return t.t("feedback.tipImprovingTrend")
        }

        if let goal = ctx.metrics.goalM, let distance = ctx.metrics.distanceM, distance < goal {
            return t.t("feedback.tipNearGoal", params: ["meters": String(goal - distance)])
        }

        return FeedbackVariants.translateVariant(
            t,
            baseKey: "feedback.tipDefault",
            count: 3,
            seed: "\(ctx.newSession.date)-tip"
        )
    }

    private static func buildCoachNarrative(
        ctx: FeedbackContext,
        t: TranslationService,
        coachGameplay: MascotGameplay
    ) -> String {
        if ctx.isFirst { return t.t("feedback.firstSession") }

        var parts: [String] = []

        if ctx.hasPb {
            parts.append(t.t("feedback.coachPersonalBest"))
        } else if let days = ctx.daysSinceLast, days >= 14 {
            parts.append(t.t("feedback.coachComeback", params: ["days": String(days)]))
        } else if let delta = ctx.paceDeltaVsRecent, delta >= 5 {
            parts.append(t.t("feedback.coachStrongSession", params: ["seconds": String(Int(delta.rounded()))]))
        } else if let delta = ctx.paceDeltaVsPrevious, delta <= -5, coachGameplay.sessionPenalty {
            parts.append(t.t("feedback.coachCriticalSession"))
        } else if let delta = ctx.paceDeltaVsPrevious, delta <= -5, ctx.metrics.avgHeartRate != nil {
            parts.append(FeedbackVariants.translateVariant(
                t,
                baseKey: "feedback.coachRecovery",
                count: 2,
                seed: "\(ctx.newSession.date)-recovery"
            ))
        } else {
            parts.append(FeedbackVariants.translateVariant(
                t,
                baseKey: "feedback.welcomeBack",
                count: 3,
                seed: "\(ctx.newSession.date)-\(ctx.metrics.distanceM ?? 0)",
                params: [
                    "distance": SwimFormatters.formatDistance(ctx.metrics.distanceM),
                    "pace": SwimFormatters.formatPace(ctx.metrics.paceSecPer100m)
                ]
            ))
        }

        if ctx.benchmarkLevel != .unknown {
            parts.append(t.t("feedback.coachBenchmark", params: [
                "level": t.t("benchmark.levels.\(ctx.benchmarkLevel.rawValue)")
            ]))
        }

        if let trend = ctx.paceTrendDelta, trend >= 4 {
            parts.append(t.t("feedback.coachTrendUp"))
        } else if ctx.monthDistance > 0 && ctx.prevMonthDistance > 0 {
            let change = Int((Double(ctx.monthDistance - ctx.prevMonthDistance) / Double(ctx.prevMonthDistance) * 100).rounded())
            if change >= 15 {
                parts.append(t.t("feedback.coachMonthUp", params: ["percent": String(change)]))
            } else if change <= -15 && !coachGameplay.positiveOnly {
                parts.append(t.t("feedback.coachMonthDown"))
            }
        }

        return parts.joined(separator: " ")
    }

    static func resolveSessionMascotMood(
        mascotId: String,
        isFirst: Bool,
        hasPb: Bool,
        paceDeltaVsPrevious: Double?,
        usedCriticalCoachLine: Bool,
        usedPaceDownMotivation: Bool
    ) -> String {
        if isFirst || hasPb { return "happy" }

        let gameplay = MascotConstants.gameplay(mascotId)
        let delta = paceDeltaVsPrevious

        if gameplay.positiveOnly { return "happy" }

        if gameplay.sessionPenalty {
            if usedCriticalCoachLine || usedPaceDownMotivation { return "disappointed" }
            if let delta, delta <= -5 { return "disappointed" }
            return "happy"
        }

        if usedPaceDownMotivation || (delta != nil && delta! <= -5) {
            return "disappointed"
        }

        return "happy"
    }

    private static func wasCriticalCoachLine(ctx: FeedbackContext, coachGameplay: MascotGameplay) -> Bool {
        if ctx.isFirst || ctx.hasPb { return false }
        if let days = ctx.daysSinceLast, days >= 14 { return false }
        if let delta = ctx.paceDeltaVsRecent, delta >= 5 { return false }
        return coachGameplay.sessionPenalty
            && ctx.paceDeltaVsPrevious != nil
            && ctx.paceDeltaVsPrevious! <= -5
    }

    static func isPositiveInsight(_ insight: String) -> Bool {
        InsightPolarity.isPositiveInsight(insight)
    }

    // MARK: - Helpers

    private static func sessionsForStats(_ allSessions: [SwimSession], newSession: SwimSession?) -> [SwimSession] {
        let stats = SwimAnalysis.statsSessions(allSessions)
        guard let newSession, !newSession.excludeFromStats else { return stats }
        if stats.contains(where: { $0.id == newSession.id }) { return stats }
        return SwimAnalysis.sortedSessions(stats + [newSession])
    }

    private static func previousSession(_ sessions: [SwimSession], currentId: String) -> SwimSession? {
        let sorted = SwimAnalysis.sortedSessions(sessions)
        guard let idx = sorted.firstIndex(where: { $0.id == currentId }), idx > 0 else { return nil }
        return sorted[idx - 1]
    }

    private static func recentPriorSessions(_ sessions: [SwimSession], currentId: String, limit: Int) -> [SwimSession] {
        let sorted = SwimAnalysis.sortedSessions(sessions)
        guard let idx = sorted.firstIndex(where: { $0.id == currentId }), idx > 0 else { return [] }
        let start = max(0, idx - limit)
        return Array(sorted[start..<idx])
    }

    private static func personalBests(_ sessions: [SwimSession], excludeId: String) -> PersonalBests {
        let others = sessions.filter { $0.id != excludeId }
        return PersonalBests(
            fastestPace: others.compactMap(\.metrics.paceSecPer100m).filter { $0 > 0 }.min(),
            longestDistance: others.compactMap(\.metrics.distanceM).max(),
            mostLaps: others.compactMap(\.metrics.laps).max()
        )
    }

    private static func daysSincePrevious(_ sessions: [SwimSession], currentId: String, currentDate: String) -> Int? {
        guard let previous = previousSession(sessions, currentId: currentId) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let current = formatter.date(from: currentDate),
              let prev = formatter.date(from: previous.date) else { return nil }
        return Int((current.timeIntervalSince(prev) / 86_400).rounded())
    }

    private static func weeklyVolume(_ sessions: [SwimSession], referenceDate: String) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let ref = formatter.date(from: referenceDate) else { return 0 }
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let weekday = calendar.component(.weekday, from: ref)
        let daysFromMonday = (weekday + 5) % 7
        guard let weekStart = calendar.date(byAdding: .day, value: -daysFromMonday, to: ref) else { return 0 }

        return SwimAnalysis.statsSessions(sessions)
            .filter { session in
                guard let date = formatter.date(from: session.date) else { return false }
                return date >= weekStart
            }
            .compactMap(\.metrics.distanceM)
            .reduce(0, +)
    }

    private static func monthDistance(_ sessions: [SwimSession], monthKey: String) -> Int {
        sessions
            .filter { $0.date.hasPrefix(monthKey) }
            .compactMap(\.metrics.distanceM)
            .reduce(0, +)
    }

    private static func shiftMonthKey(_ monthKey: String, by delta: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: "\(monthKey)-01"),
              let shifted = Calendar.current.date(byAdding: .month, value: delta, to: date) else {
            return monthKey
        }
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: shifted)
    }

    private static func dominantStroke(_ strokes: StrokeDistances) -> DominantStroke? {
        let entries = strokeKeys.compactMap { key -> (String, Int)? in
            let value: Int?
            switch key {
            case "mixedM": value = strokes.mixedM
            case "breaststrokeM": value = strokes.breaststrokeM
            case "freestyleM": value = strokes.freestyleM
            case "backstrokeM": value = strokes.backstrokeM
            case "butterflyM": value = strokes.butterflyM
            default: value = nil
            }
            guard let value, value > 0 else { return nil }
            return (key, value)
        }
        guard !entries.isEmpty else { return nil }
        let total = entries.reduce(0) { $0 + $1.1 }
        let top = entries.max(by: { $0.1 < $1.1 })!
        return DominantStroke(key: top.0, meters: top.1, share: Double(top.1) / Double(total))
    }

    private static func recentCount(ctx: FeedbackContext, days: Int) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let current = formatter.date(from: ctx.newSession.date) else { return 0 }
        return ctx.allSessions.filter { session in
            guard let date = formatter.date(from: session.date) else { return false }
            let diff = current.timeIntervalSince(date) / 86_400
            return diff >= 0 && diff <= Double(days)
        }.count
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
