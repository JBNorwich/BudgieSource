// Copyright 2026 Joseph Baldwin
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
// documentation files (the "Software"), to deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of
// the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
// OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
// OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import Foundation
import SwiftUI
import Combine
#if !os(macOS)
import HealthKit
#endif

class TodayLump: ObservableObject {
    // Variables that need to be updated upon creation
    @Published var activeCalories: Int = 0
    @Published var basalCalories: Int = 0
    @Published var eatenCalories: Int = 0
    @Published var projectedActive: Int = 0
    @Published var projectedBasal: Int = 0
    @Published var waterToday: Int = 0
    @Published var weightToday: Double = 0
    @Published var weightYesterday: Double = 0
    @Published var lastWeightDate: Date? = nil
    @Published var prevWeightDate: Date? = nil
    @Published var averageDeficit: Int = 0
    @Published var lastWeekAvgWeight: Double = 0
    @Published var prevWeekAvgWeight: Double = 0
    @Published var foodDaysLoggedFortnight: Int = 0
    
    #if !os(macOS)
    @Published var activitySummary: HKActivitySummary = HKActivitySummary()
    #endif
    
    @Published private(set) var totalBudget: Int = 1200
    @Published private(set) var budgetAtCap: Bool = false
    @Published private(set) var budgetAtMin: Bool = false
    
    // food data
    /// A list of Meal()s in the database that don't include any that don't have food logged today.
    @Published var cleansedMealList: [Meal] = []
    /// A list of all Meal()s in the database, whether they've got food in them or not.
    @Published var allMeals: [Meal] = []
    /// The total calories for each meal that has calories in it.
    @Published var mealTotalList: [UUID:Int] = [:]
    @Published var foodList: [CalorieEntry] = []
    @Published var healthKitCalories: Int = 0
    @Published var eatenProtein: Int = 0
    @Published var eatenFat: Int = 0
    @Published var eatenCarbs: Int = 0
    
    // flags for estimation of data
    @Published var basalEstimated: Bool = false
    @Published var activeEstimated: Bool = false
    
    // signals re. data updates
    @Published var updateInProgress: Bool = false
    @Published var updateQueued: Bool = false
    @Published var lastUpdate: Date = Date()
    
    /// Whether a request that queued behind an in-flight update wanted to publish the snapshot. OR-combined so a foreground publish isn't lost when it queues behind a background pass.
    var queuedPublishSnapshot: Bool = false
    
    /// Whether the measured week genuinely shows movement AWAY from the goal — as distinct from
    /// there simply being no target to project from. Only meaningful once food is logged consistently.
    var movingAwayFromGoal: Bool {
        consistentlyLoggedFood && measuredGoalRate <= 0
    }

    func recalculateBudget() {
        let result = computeBudget(averageBurn: totalProjCalories)
        totalBudget = result.budget
        budgetAtCap = result.atCap
        budgetAtMin = result.atMin
    }
    
    /// The "real" budget that would be calculated if the budget was not capped. Only relevant if the user has turned on capping; otherwise this will just return whatever the budget is.
    var realBudget: Int {
        return max(totalProjCalories - settingsObj.desiredDeficit, 1200)
    }
    
    /// The ledger adjustment applied because of the cap: capBudgetCals minus the uncapped budget, so it is NEGATIVE while the cap is active. NewDataView displays it as a deduction row, like the target deficit.
    var budgetOverCap: Int {
        return settingsObj.capBudgetCals - self.realBudget
    }
    
    /// The total amount remaining to eat from the user's budget.
    var totalBudgetRem: Int {
        return self.totalBudget - self.eatenCalories
    }
    
    /// The amount that the user can eat now, as weighted against their last meal time. Not meaningful in allocated budget mode, so in that mode, will return the user's remaining budget.
    var canEatNow: Int {
        guard self.totalBudget != 0 else { return 0 }
        // With meal allocations on, pacing is handled per-meal, so the blob shows the
        // plain remaining daily budget rather than the time-weighted figure — keeping it
        // consistent with, and never systematically below, the individual meal targets.
        if settingsObj.useMealAllocations {
            return self.totalBudgetRem
        }
        return weightCanEatNow(input: self.totalBudget) - self.eatenCalories
    }
    
    var totalProjCalories: Int {
        return self.activeCalories + self.basalCalories + self.projectedActive + self.projectedBasal
    }
    
    /// The percentage of the user's calorie budget that they have eaten.
    var progressToday: Double {
        if self.totalBudget != 0 {
            return (Double(self.eatenCalories) / Double(self.totalBudget))
        } else {
            return 0
        }
    }
    
    /// The user's "target" calories - how much of their budget, in total, the app thinks the user can eat while keeping some aside for their final meal.
    /// With meal allocations on, pacing is per-meal rather than by clock, so the target is simply the whole day's budget.
    var currentTarget: Int {
        if settingsObj.useMealAllocations {
            return self.totalBudget
        }
        return weightCanEatNow(input: self.totalBudget)
    }
    
    var progressAgainstTarget: Double {
        clampedProgress(eaten: self.eatenCalories, target: self.currentTarget)
    }
    
    var gaugeNumber: Int {
        Int(self.progressAgainstTarget * 100) - 100
    }
    
    var calsOutNow: Int {
        return self.activeCalories + self.basalCalories
    }
    
    var waterGoalDone: Double {
        min(max(Double(self.waterToday) / Double(self.effectiveWaterGoal), 0), 1)
    }

    var waterGoalRem: Int {
        max(self.effectiveWaterGoal - self.waterToday, 0)
    }
    
    // WEIGHT RELATED CALCULATED VARIABLES

    /// A smoothed "current weight": the trailing weekly average when available, else the latest reading.
    /// Used for trend analysis so day-to-day scale noise doesn't make them jump.
    var currentWeight: Double {
        lastWeekAvgWeight != 0 ? lastWeekAvgWeight : weightToday
    }

    /// The amount of weight (kg) the user has to go to meet their goal.
    var weightToGo: Double {
        guard settingsObj.weightGoal != 0, weightToday != 0 else { return 0 }
        if weightGoalMet { return 0 }
        let remaining = settingsObj.surplusMode
            ? settingsObj.weightGoal - weightToday
            : weightToday - settingsObj.weightGoal
        return max(remaining, 0)
    }

    /// The change (kg) since the user's previous weigh-in (positive = down). Not necessarily one day.
    var changeSinceLastReading: Double {
        return self.weightYesterday - self.weightToday
    }

    /// Progress from start weight toward goal, 0 (just started) → 1 (met).
    var weightGoalProgress: Double {
        guard settingsObj.weightGoal != 0, settingsObj.startWeight != 0, weightToday != 0 else { return 0 }
        if weightGoalMet { return 1 }
        let total = settingsObj.surplusMode
            ? settingsObj.weightGoal - settingsObj.startWeight
            : settingsObj.startWeight - settingsObj.weightGoal
        let done = settingsObj.surplusMode
            ? weightToday - settingsObj.startWeight
            : settingsObj.startWeight - weightToday
        guard total > 0 else { return 0 }
        return min(max(done / total, 0), 1)
    }

    /// Whether the user has reached their weight goal, respecting goal direction.
    var weightGoalMet: Bool {
        guard settingsObj.weightGoal != 0, weightToday != 0 else { return false }
        return settingsObj.surplusMode
            ? weightToday >= settingsObj.weightGoal
            : weightToday <= settingsObj.weightGoal
    }

    /// The gauge value: how much of the journey is left (1 at start → 0 at goal).
    var weightGoalRemaining: Double { 1 - weightGoalProgress }

    /// Weight change between the previous week's average and the most recent week's average (positive = down).
    var weightTrend: Double {
        return self.prevWeekAvgWeight - self.lastWeekAvgWeight
    }

    /// Expected weekly weight change from the recorded average deficit (kg), unrounded — for maths.
    private var expectedWeeklyChangeExact: Double {
        return expectedWeeklyChange(averageDeficit: self.averageDeficit)
    }

    /// Expected weekly weight loss at the recorded deficit, rounded for display.
    var expectedWeightLossAtRealDeficit: Double {
        return roundDoubleWeight(input: expectedWeeklyChangeExact)
    }

    /// How actual weight change compares to expectation. >1 better than expected, <1 worse.
    /// nil when there's no meaningful expectation to compare against (deficit ≈ 0).
    var performanceAgainstWeightTrend: Double? {
        // Both weekly averages must exist for the trend to mean anything.
        guard lastWeekAvgWeight != 0, prevWeekAvgWeight != 0 else { return nil }
        let expected = expectedWeeklyChangeExact
        guard abs(expected) > 0.001 else { return nil }
        return self.weightTrend / expected
    }
    
    /// Absolute floor (kg) for the on-target tolerance half-width. Week-to-week noise on the weight trend is roughly constant in kg regardless of deficit size, so a purely proportional ±50% band becomes far tighter than the noise at gentle deficits — a user perfectly on plan would read as "off target" on water weight alone. The floor keeps the band physically realistic; ~0.35kg is roughly one SD of the difference between two adjacent weekly averages.
    static let onTargetHalfWidthFloor: Double = 0.35

    /// Where actual weekly progress sits relative to expectation.
    enum TrendStanding { case behind, onTarget, ahead }

    /// Actual progress classified against a tolerance band that is the wider of ±50% of the
    /// expected change and `onTargetHalfWidthFloor`. Returns the standing plus the band as
    /// magnitudes in the goal direction (kg), with `lower` clamped at 0 for display. nil when
    /// there's no meaningful expectation to compare against.
    var trendStanding: (standing: TrendStanding, lower: Double, upper: Double)? {
        guard performanceAgainstWeightTrend != nil else { return nil }
        return weightTrendBand(averageDeficit: self.averageDeficit, weightTrend: self.weightTrend, surplusMode: settingsObj.surplusMode)
    }

    /// Measured daily energy imbalance in the direction of the user's goal: a deficit when
    /// losing, a surplus when gaining. Positive means they're moving toward their goal.
    private var measuredGoalRate: Int {
        settingsObj.surplusMode ? -averageDeficit : averageDeficit
    }

    /// The rate the user's actual progress implies, adjusting the measured rate by performance.
    var realDeficit: Int {
        guard measuredGoalRate > 0, let performance = performanceAgainstWeightTrend else { return 0 }
        let doubleCalc = Double(measuredGoalRate) * performance
        guard doubleCalc.isFinite, !doubleCalc.isNaN else { return 0 }
        return Int(doubleCalc)
    }

    /// Whether the user has logged food on enough of the last 14 days for target-tracking figures to be meaningful.
    var consistentlyLoggedFood: Bool {
        foodDaysLoggedFortnight >= 12
    }

    /// The daily rate (cal/day, always positive, in the goal direction) to base "time to goal"
    /// projections on. Uses the user's measured rate once they've logged food consistently
    /// enough for it to be meaningful; otherwise falls back to their planned target.
    var goalProjectionDeficit: Int {
        guard consistentlyLoggedFood, measuredGoalRate > 0 else {
            return abs(settingsObj.desiredDeficit)
        }
        return realDeficit > 0 ? realDeficit : measuredGoalRate
    }

    /// Whether there's a meaningful "time to goal" estimate to show — i.e. we're not moving
    /// the wrong way (surplus when losing, deficit when gaining) and the projection is positive.
    var hasGoalTimeEstimate: Bool {
        if consistentlyLoggedFood && measuredGoalRate <= 0 { return false }
        return goalProjectionDeficit > 0
    }
    
    /// Per-meal calorie targets when allocations are enabled. Non-Snacks meals get round(percent% × budget); Snacks/Other absorbs the remainder and any rounding.
    /// Returns an empty dictionary when the feature is off.
    var mealAllocationTargets: [UUID: Int] {
        guard settingsObj.useMealAllocations else { return [:] }
        let budget = self.totalBudget
        let snacksUUID = settingsObj.snacksUUID
        var targets: [UUID: Int] = [:]
        var allocated = 0
        for meal in allMeals where meal.mealUUID != snacksUUID {
            let t = Int((meal.budgetPercent / 100 * Double(budget)).rounded())
            targets[meal.mealUUID] = t
            allocated += t
        }
        if let snacksUUID {
            targets[snacksUUID] = max(budget - allocated, 0)
        }
        return targets
    }
    
    /// The user's water goal, topped up by 1 ml per active calorie burned today when
    /// the "increase goal with activity" setting is on.
    var effectiveWaterGoal: Int {
        waterGoal(activeCalories: activeCalories)
    }
    
    /// Applies a budget computed on another device (the iPhone). Used on platforms without HealthKit, where `recalculateBudget()` can't run because there's no activity data.
    func applyBudgetSnapshot(budget: Int, atCap: Bool, atMin: Bool) {
        totalBudget = budget
        budgetAtCap = atCap
        budgetAtMin = atMin
    }
}

/// Struct that holds an individual data point of weight.
struct WeightPoint: Identifiable {
    let id = UUID()
    let date: Date
    let kilos: Double
}

/// Macros eaten today, split by source so the HealthKit (other-app) portion can be snapshotted for the Mac, mirroring how eaten calories carry an `hk` part.
struct EatenMacros {
    var hkProtein = 0, hkFat = 0, hkCarbs = 0
    var ownProtein = 0, ownFat = 0, ownCarbs = 0
    var protein: Int { hkProtein + ownProtein }
    var fat: Int { hkFat + ownFat }
    var carbs: Int { hkCarbs + ownCarbs }
}

/// One day's calorie picture for the calorie chart: HealthKit active/basal burn plus eaten calories
/// (HealthKit + Budgie's own logged entries, merged). `totalCals`/`deficit` are derived so callers
/// never need to re-add the pieces themselves.
class ChartDataLump: Identifiable {
    var id: UUID = UUID()
    var date: Date = Date()
    var eatenCals: Int = 0
    var activeCals: Int = 0
    var basalCals: Int = 0
    var totalCals: Int { activeCals + basalCals }
    /// Positive when in deficit, negative when in surplus.
    var deficit: Int { totalCals - eatenCals }
}

/// One day's macro totals (Budgie + HealthKit, already summed), in grams.
struct MacroPoint: Identifiable {
    let id = UUID()
    let date: Date
    let protein: Int
    let fat: Int
    let carbs: Int
}

/// One day's water intake (Budgie + HealthKit, already summed), in millilitres.
struct WaterPoint: Identifiable {
    let id = UUID()
    let date: Date
    let millilitres: Int
}

/// The water goal (ml) given a day's active-calorie burn: the base goal topped up 1ml per active
/// calorie when "increase goal with activity" is on, floored at 1. Shared by
/// `TodayLump.effectiveWaterGoal` (today's live figure, using today's `activeCalories`) and
/// `waterGoalSeries` (each historical day's own figure, using that day's `activeCals`) so the two
/// can never drift apart.
func waterGoal(activeCalories: Int) -> Int {
    let base = settingsObj.waterFromActivity ? settingsObj.waterGoal + max(activeCalories, 0) : settingsObj.waterGoal
    return max(base, 1)
}

/// Builds a day-by-day water-goal series (ml) for `forDates`, keyed by date, from `calorieData`'s
/// per-day active calories — the historical generalisation of `TodayLump.effectiveWaterGoal`, which
/// only ever reflects today. Constant across days when "increase goal with activity" is off.
func waterGoalSeries(calorieData: [ChartDataLump], forDates: [Date]) -> [Date: Int] {
    let calendar = Calendar.current
    let activeByDay = Dictionary(calorieData.map { (calendar.startOfDay(for: $0.date), $0.activeCals) }, uniquingKeysWith: { a, _ in a })
    return Dictionary(uniqueKeysWithValues: forDates.map { date in
        let day = calendar.startOfDay(for: date)
        return (day, waterGoal(activeCalories: activeByDay[day] ?? 0))
    })
}

/// Expected weekly weight change (kg) implied by a daily calorie deficit, unrounded. Positive when
/// `averageDeficit` is positive (i.e. a deficit implies loss); 7700 kcal ≈ 1kg of body fat.
func expectedWeeklyChange(averageDeficit: Int) -> Double {
    Double(averageDeficit * 7) / 7700
}

/// The calorie budget for a given average daily burn (kcal): subtract the desired deficit/surplus,
/// floor at 1,200kcal, then apply the optional cap. The exact formula `TodayLump.recalculateBudget()`
/// uses for "today" (there, `averageBurn` is `totalProjCalories`) — generalised here so a historical
/// day's budget can be derived from its own trailing-average burn instead of today's live figure,
/// e.g. for a day-varying percentage-mode macro goal on the chart.
func computeBudget(averageBurn: Int) -> (budget: Int, atCap: Bool, atMin: Bool) {
    let uncapped = averageBurn - settingsObj.desiredDeficit
    var budget = max(uncapped, 1200)
    // Capping exists to stop a deficit budget ballooning when you burn more than expected;
    // it makes no sense against a surplus, so it's ignored in surplus mode.
    let atCap = settingsObj.capBudget && !settingsObj.surplusMode && budget > settingsObj.capBudgetCals
    if atCap { budget = max(settingsObj.capBudgetCals, 1200) }
    // Only flag the minimum when the 1,200 floor actually kicked in — not when the
    // budget legitimately works out at exactly 1,200.
    let atMin = uncapped < 1200 || (atCap && settingsObj.capBudgetCals < 1200)
    return (budget, atCap, atMin)
}

/// Trailing-average window (days) used throughout the chart's rolling-average calculations — the
/// weight trend and the macro/water goal series. Callers that need to pad a fetch so a rolling
/// average has a full window from the first requested day (e.g. `macroGoalSeries`'s caller) should
/// pad by this many days rather than a bare literal, so the window can't drift out of sync with it.
let rollingAverageDays = 7

/// The trailing N-day average of a day-keyed series, ending at (and including) `day` — nil if none
/// of those days have a value. The shared rolling-average building block behind the weight-trend
/// series and the historical per-day budgets used for macro-goal charting.
func trailingAverage(_ values: [Date: Double], endingAt day: Date, days: Int = rollingAverageDays, calendar: Calendar = .current) -> Double? {
    var total = 0.0, count = 0
    for offset in 0..<days {
        guard let d = calendar.date(byAdding: .day, value: -offset, to: day) else { continue }
        if let v = values[calendar.startOfDay(for: d)] { total += v; count += 1 }
    }
    guard count > 0 else { return nil }
    return total / Double(count)
}

/// Days of history needed before the first visible chart day to compute a weight-trend band there:
/// the band compares a rolling average against ANOTHER rolling average ending `rollingAverageDays`
/// before that, so two chained windows of history are needed before any band value exists.
let weightTrendLookbackDays = rollingAverageDays * 2

/// Classifies an observed weekly weight-trend change against a tolerance band derived from the
/// expected change at a given average deficit. Shared by `TodayLump.trendStanding` (evaluated for
/// the current week) and `weightTrendSeries` (evaluated once per historical day) so the "Expected
/// …–…" figure shown on `WeightView` and the chart's expected-range band can never drift apart.
func weightTrendBand(averageDeficit: Int, weightTrend: Double, surplusMode: Bool) -> (standing: TodayLump.TrendStanding, lower: Double, upper: Double) {
    // Magnitudes in the goal direction: a deficit expects loss, a surplus expects gain.
    let expected = abs(expectedWeeklyChange(averageDeficit: averageDeficit))
    let actual = surplusMode ? -weightTrend : weightTrend
    let halfWidth = max(0.5 * expected, TodayLump.onTargetHalfWidthFloor)
    let standing: TodayLump.TrendStanding =
        actual > expected + halfWidth ? .ahead :
        actual < expected - halfWidth ? .behind : .onTarget
    return (standing, max(0, expected - halfWidth), expected + halfWidth)
}

/// One day's weight-trend picture for the weight chart: the raw logged entry (if any), the smoothed
/// trailing weekly average, and the range that average was expected to fall in given the recorded
/// deficit — the day-by-day generalisation of `TodayLump`'s single-point "Expected …" figure.
struct WeightTrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let actualWeight: Double?
    let trendWeight: Double?
    let expectedLower: Double?
    let expectedUpper: Double?
}

/// Builds a day-by-day trend line + expected-range band from raw weight points and a per-day deficit
/// series, using the same maths as `TodayLump.trendStanding`. For each day, `trendWeight` is the
/// trailing 7-day average of `weightPoints` ending that day (nil until 7 days of coverage exist).
/// `expectedLower`/`expectedUpper` compare that trend against the trend 7 days earlier — mirroring
/// how `TodayLump` compares "last week's average" against "the week before's average" — using the
/// trailing 7-day average deficit ending on the day as the expectation.
func weightTrendSeries(weightPoints: [WeightPoint], deficitByDay: [Date: Int], surplusMode: Bool) -> [WeightTrendPoint] {
    let calendar = Calendar.current
    guard let firstDate = weightPoints.map(\.date).min() else { return [] }
    let lastDate = weightPoints.map(\.date).max() ?? firstDate

    let weightByDay = Dictionary(weightPoints.map { (calendar.startOfDay(for: $0.date), $0.kilos) }, uniquingKeysWith: { a, _ in a })
    let deficitByDay = Dictionary(deficitByDay.map { (calendar.startOfDay(for: $0.key), Double($0.value)) }, uniquingKeysWith: { a, _ in a })

    var points: [WeightTrendPoint] = []
    var day = calendar.startOfDay(for: firstDate)
    let end = calendar.startOfDay(for: lastDate)
    while day <= end {
        let trend = trailingAverage(weightByDay, endingAt: day, calendar: calendar)
        var expectedLower: Double?
        var expectedUpper: Double?
        if let trend,
           let anchorDay = calendar.date(byAdding: .day, value: -7, to: day),
           let anchorTrend = trailingAverage(weightByDay, endingAt: anchorDay, calendar: calendar),
           let avgDeficit = trailingAverage(deficitByDay, endingAt: day, calendar: calendar) {
            let band = weightTrendBand(averageDeficit: Int(avgDeficit.rounded()), weightTrend: anchorTrend - trend, surplusMode: surplusMode)
            let (lo, hi): (Double, Double) = surplusMode
                ? (anchorTrend + band.lower, anchorTrend + band.upper)
                : (anchorTrend - band.upper, anchorTrend - band.lower)
            expectedLower = lo
            expectedUpper = hi
        }
        points.append(WeightTrendPoint(date: day, actualWeight: weightByDay[day],
                                       trendWeight: trend, expectedLower: expectedLower, expectedUpper: expectedUpper))
        guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
        day = next
    }
    return points
}

/// One day's macro goal, in grams. Constant across days for a fixed-gram goal; varies day to day for
/// a percentage-of-budget goal, since each day's budget is derived from THAT day's own trailing
/// average burn rather than frozen at whatever today's budget happens to be. nil fields mean "no
/// goal set for that macro" (matches `macroGoalGrams`'s own nil).
struct MacroGoalPoint: Identifiable {
    let id = UUID()
    let date: Date
    let protein: Int?
    let fat: Int?
    let carbs: Int?
}

/// Builds a day-by-day macro-goal series for `forDates`, from `calorieData` (which should cover at
/// least 7 days before the earliest date in `forDates`, so the first visible day still gets a full
/// trailing average rather than a partial/noisy one). Each day's own trailing-average burn feeds
/// `computeBudget` then `settingsObj.macroGoalGrams(budget:)` — the same two functions
/// `TodayLump`/`MacroSummaryView` use for "today" — so a percentage-mode goal genuinely tracks each
/// day's own budget instead of freezing at today's, and stays consistent with what's shown elsewhere.
///
/// `todayBudget`, when supplied, is used verbatim for today's point instead of a trailing average of
/// `calorieData` — that average is built from `burnSeries`'s actually-measured burn only, which for
/// today is necessarily a partial, still-in-progress figure, so it disagrees with the live budget
/// (`TodayLump.totalBudget`, which folds in a projected remainder) shown everywhere else on today.
func macroGoalSeries(calorieData: [ChartDataLump], forDates: [Date], todayBudget: Int? = nil) -> [MacroGoalPoint] {
    let calendar = Calendar.current
    let totalCalsByDay = Dictionary(calorieData.map { (calendar.startOfDay(for: $0.date), Double($0.totalCals)) }, uniquingKeysWith: { a, _ in a })
    return forDates.map { rawDate in
        let day = calendar.startOfDay(for: rawDate)
        if let todayBudget, calendar.isDateInToday(day) {
            let goals = settingsObj.macroGoalGrams(budget: todayBudget)
            return MacroGoalPoint(date: day, protein: goals.protein, fat: goals.fat, carbs: goals.carbs)
        }
        guard let avgBurn = trailingAverage(totalCalsByDay, endingAt: day, calendar: calendar) else {
            return MacroGoalPoint(date: day, protein: nil, fat: nil, carbs: nil)
        }
        let budget = computeBudget(averageBurn: Int(avgBurn.rounded())).budget
        let goals = settingsObj.macroGoalGrams(budget: budget)
        return MacroGoalPoint(date: day, protein: goals.protein, fat: goals.fat, carbs: goals.carbs)
    }
}
