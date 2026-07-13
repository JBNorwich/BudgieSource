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

import WidgetKit
import SwiftUI
import HealthKit

let settingsObj = CloudSettings()
let healthStore = HKHealthStore()
let dataStore = HealthData.shared

struct TinyMeter: View {
    var leftToEat: Int
    var progress: Double
    var totalBudg: Int
    var projBasal: Int
    var surplusMode: Bool = false

    private var pathDiff: Double {
        let d = progress / getPercentOfDayDone()
        return d.isFinite ? d : 0
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(.shadow(.drop(color: .black, radius: 4)))
                .fill(budgetBlobColour(canEatNow: leftToEat, surplusMode: surplusMode))
            Circle()
                .trim(from: 0, to: progress)
                .rotation(Angle(degrees: -90))
                // GOES CLOCKWISE FROM EAST
                .fill(.clear)
                .stroke(budgetPathColour(diff: pathDiff, budget: totalBudg, projectedBasal: projBasal).gradient, style:StrokeStyle(lineWidth: 10, lineCap: .round))
                .shadow(radius: 10)
            Text(abs(leftToEat).formatted())
                .fontWeight(.heavy)
                .font(.system(size:14))
                .minimumScaleFactor(0.01)
                .scaledToFit()
                .contentMargins(50)
                .contentTransition(.numericText())
                .shadow(radius: 5)
                .foregroundColor(.white)
            }
        }
    }

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> BudgieEntry {
        BudgieEntry(date: Date(), leftToEat: 428, progressDbl: 0, totalBudgRem: 890, totalBudg: 3560, projBasal: 2000, surplusMode: false, useAllocations: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (BudgieEntry) -> ()) {
        let entry = BudgieEntry(date: Date(), leftToEat: 428, progressDbl: 0.75, totalBudgRem: 890, totalBudg: 3560, projBasal: 2000, surplusMode: false, useAllocations: false)
        completion(entry)
    }

    /// "Can eat now" at a given time, from the snapshot's raw numbers — the same
    /// square-law ramp as weightCanEatNow(), but taking its inputs as parameters
    /// because the widget can't trust settingsObj in its own process.
    private func canEat(at date: Date, budget: Int, eaten: Int, finalMealTime: Int) -> Int {
        let cal = Calendar.current
        let mins = (60 * cal.component(.hour, from: date)) + cal.component(.minute, from: date)
        var factor = Double(mins + 1) / Double(max(finalMealTime, 1))
        if factor > 1 { factor = 1 } else { factor *= factor }
        return Int(Double(budget) * factor) - eaten
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // Pure read of the snapshot the app wrote — no HealthKit, no SwiftData, so this
        // completes instantly and can't hit the extension's memory or lock-state limits.
        let group = UserDefaults(suiteName: "group.JoeBaldwin.Budgie")
        let budget = group?.integer(forKey: "widgetTotalBudget") ?? 0
        let eaten = group?.integer(forKey: "widgetEatenCalories") ?? 0
        let projBasal = group?.integer(forKey: "widgetProjectedBasal") ?? 0
        let finalMeal = (group?.object(forKey: "widgetFinalMealTime") as? Int) ?? 1080
        let surplus = group?.bool(forKey: "widgetSurplusMode") ?? false
        let useAllocations = group?.bool(forKey: "widgetUseAllocations") ?? false
        let progress = budget != 0 ? Double(eaten) / Double(budget) : 0

        let cal = Calendar.current
        let now = Date()
        let todayStart = cal.startOfDay(for: now)
        let nextMidnight = cal.date(byAdding: .day, value: 1, to: todayStart) ?? now.addingTimeInterval(3 * 60 * 60)

        // The snapshot only describes the day it was taken. Once the clock rolls past midnight the
        // budget resets and yesterday's eaten total is meaningless, so show a neutral "stale" entry
        // rather than a confidently wrong "can eat now" until the app next refreshes.
        let snapshotDay = (group?.object(forKey: "widgetSnapshotDay") as? Double).map { Date(timeIntervalSince1970: $0) }
        let isFresh = snapshotDay.map { cal.isDate($0, inSameDayAs: todayStart) } ?? false

        guard isFresh else {
            let entry = BudgieEntry(date: now, leftToEat: 0, progressDbl: 0, totalBudgRem: 0,
                                    totalBudg: 0, projBasal: 0, surplusMode: surplus,
                                    useAllocations: useAllocations, isStale: true)
            // Check back soon — the app usually refreshes shortly after midnight.
            let retry = cal.date(byAdding: .minute, value: 30, to: now) ?? now.addingTimeInterval(1800)
            completion(Timeline(entries: [entry], policy: .after(retry)))
            return
        }

        // The data only changes when the app updates, but "can eat now" ramps with the
        // clock — so emit an entry every 15 minutes for the next 3 hours, then repeat.
        // With meal allocations on, pacing is per-meal, so there's no ramp to follow:
        // show the plain daily remainder instead, matching the phone's meter.
        var entries: [BudgieEntry] = []
        for i in 0..<12 {
            let entryDate = now.addingTimeInterval(Double(i) * 15 * 60)
            let leftToEat = useAllocations
                ? budget - eaten
                : canEat(at: entryDate, budget: budget, eaten: eaten, finalMealTime: finalMeal)
            entries.append(BudgieEntry(date: entryDate,
                                       leftToEat: leftToEat,
                                       progressDbl: progress,
                                       totalBudgRem: budget - eaten,
                                       totalBudg: budget,
                                       projBasal: projBasal,
                                       surplusMode: surplus,
                                       useAllocations: useAllocations))
        }

        // Reload after the last entry as before, but never later than midnight, so the stale
        // check trips promptly when the day rolls over even if the app hasn't refreshed.
        let reload = min(entries.last?.date ?? now, nextMidnight)
        completion(Timeline(entries: entries, policy: .after(reload)))
    }
}

struct BudgieEntry: TimelineEntry {
    let date: Date
    let leftToEat: Int
    let progressDbl: Double
    let totalBudgRem: Int
    let totalBudg: Int
    let projBasal: Int
    let surplusMode: Bool
    let useAllocations: Bool
    var isStale: Bool = false
}

struct BudgieWidgetEntryView : View {
    var entry: Provider.Entry

    private var staleView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("BUDGET").font(.caption).foregroundStyle(.secondary)
            Text("—").font(.title).fontWeight(.heavy)
            Spacer()
            Text("Open Budgie Diet to refresh")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    var body: some View {
        if entry.isStale {
            staleView
        } else {
            ZStack {
                VStack {
                    Spacer()
                    HStack {
                        Image("Budgie")
                            .resizable()
                            .frame(maxWidth: 58, maxHeight: 50)
                            .offset(x: -25, y: 25)
                        Spacer()
                    }
                }
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        TinyMeter(leftToEat: entry.leftToEat, progress: entry.progressDbl, totalBudg: entry.totalBudg, projBasal: entry.projBasal, surplusMode: entry.surplusMode)
                            .frame(maxWidth: 50, maxHeight: 50)
                    }
                }
                VStack {
                    VStack {
                        HStack {
                            Text(budgetStatusLabel(leftToEat: entry.leftToEat, surplusMode: entry.surplusMode, usingAllocations: entry.useAllocations).uppercased())
                                .font(.caption)
                            Spacer()
                        }
                        HStack {
                            Text(abs(entry.leftToEat).formatted())
                                .font(.title)
                            Spacer()
                        }

                        // no value in showing left to eat if it's the same as the remaining budget
                        if entry.totalBudgRem != entry.leftToEat {
                            HStack {
                                Text((entry.totalBudgRem > -1 ? "Budget left" : "Over budget").uppercased())
                                    .font(.caption)
                                Spacer()
                            }
                            HStack {
                                Text(abs(entry.totalBudgRem).formatted())
                                    .font(.title)
                                Spacer()
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
    }
}

/// Widget view for `accessoryCircular`
struct CircularWidgetView: View {
    let entry: BudgieEntry

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AccessoryWidgetBackground()
                VStack {
                    if entry.isStale {
                        Gauge(value: 0) { Text(verbatim: "—") }
                            .gaugeStyle(.accessoryCircularCapacity)
                    } else {
                        Gauge(value: entry.progressDbl) {
                            Text(verbatim: entry.leftToEat.formatted())
                        }.gaugeStyle(.accessoryCircularCapacity)
                    }
                }
            }
            .containerBackground(for: .widget) { }
        }
    }
}

struct ViewSizeWidgetView: View {
    let entry: BudgieEntry
    
    let gradient = LinearGradient(
        colors: [Color.cyan, Color.blue],
        startPoint: .top, endPoint: .bottom)

    // Obtain the widget family value
    @Environment(\.widgetFamily)
    var family

    var body: some View {

        switch family {
        case .accessoryCircular:
            CircularWidgetView(entry: entry)
        default:
            // UI for Home Screen widget
            BudgieWidgetEntryView(entry: entry)
                .containerBackground(gradient, for: .widget)
        }
    }
}

struct BudgieWidget: Widget {
    let kind: String = "BudgieWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ViewSizeWidgetView(entry: entry)
        }
        .configurationDisplayName("Current status")
        .description("This shows your current budget status.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}
//
//#Preview(as: .systemSmall) {
//    BudgieWidget()
//} timeline: {
//    BudgieEntry(date: Date(), leftToEat: 428, progressDbl: 0.75, totalBudgRem: 890, totalBudg: 3560, projBasal: 2000)
//}
