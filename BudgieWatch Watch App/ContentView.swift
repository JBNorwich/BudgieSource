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

import SwiftUI
import HealthKitUI
import WatchKit

struct ContentView: View {
    @StateObject var todayLump: TodayLump = TodayLump()
    @Environment(\.scenePhase) private var scenePhase
    @State private var hkTrigger = false
    @State private var quickCals: Int = 100
    private enum LogTarget { case calories, water }
    @State private var calConfirmation: String? = nil
    @State private var waterConfirmation: String? = nil
    @State private var confirmGeneration = 0
    @State private var showingCalPad = false

    private struct MetricCell: View {
        let title: String
        let value: String
        var color: Color = .primary

        var body: some View {
            VStack(spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private struct SectionHeader: View {
        let title: String

        var body: some View {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
            }
            .padding(.top, 8)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 4) {
                    Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                        GridRow {
                            MetricCell(title: budgetStatusLabel(leftToEat: todayLump.canEatNow),
                                       value: abs(todayLump.canEatNow).formatted(),
                                       color: budgetBlobColour(canEatNow: todayLump.canEatNow))
                            MetricCell(title: todayLump.totalBudgetRem > -1 ? "Left today" : "Over by",
                                       value: abs(todayLump.totalBudgetRem).formatted(),
                                       color: todayLump.totalBudgetRem > -1 ? .primary : .red)
                        }
                        GridRow {
                            MetricCell(title: "Eaten", value: todayLump.eatenCalories.formatted())
                            MetricCell(title: "Budget", value: todayLump.totalBudget.formatted())
                        }
                    }
                    .onTapGesture {
                        Task { await dataStore.updateLump(todayLump: todayLump) }
                    }

                    if todayLump.activeEstimated == true || todayLump.basalEstimated == true {
                        Label("Calories out are estimated, so your budget isn't based on real activity.", systemImage: "info.circle")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    SectionHeader(title: "Log quick calories")
                    Stepper(value: $quickCals, in: 25...5000, step: 25) {
                        // Tapping the value opens a number pad for an arbitrary amount —
                        // the filled pill signals that it's tappable.
                        Button {
                            showingCalPad = true
                        } label: {
                            Text("\(quickCals.formatted()) kcal")
                                .font(.headline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 12)
                                .background(.quaternary, in: Capsule())
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                    .sheet(isPresented: $showingCalPad) {
                        WatchNumberPad(prompt: "Calories") { value in
                            let amount = min(value, 5000)
                            quickCals = amount
                            logCalories(amount)
                        }
                    }
                    Button {
                        logCalories(quickCals)
                    } label: {
                        Label("Log calories", systemImage: "fork.knife")
                    }
                    if let calConfirmation {
                        ConfirmationLabel(text: calConfirmation)
                    }

                    SectionHeader(title: "Log water")
                    HStack(spacing: 4) {
                        Button("250ml", systemImage: "drop.fill") { logWater(250) }
                        Button("500ml", systemImage: "drop.fill") { logWater(500) }
                    }
                    if let waterConfirmation {
                        ConfirmationLabel(text: waterConfirmation)
                    }
                }
            }
            .navigationTitle("Budgie Diet")
            .navigationBarTitleDisplayMode(.inline)

            .onChange(of: scenePhase) {
                guard scenePhase == .active else {
                   return
                }
                // Mac pulls the latest iCloud key-value settings on every foreground; the watch
                // never did, so a deficit/goal changed on the phone could lag here until the OS's
                // own background propagation caught up.
                settingsObj.sync()
                Task {
                    await dataStore.updateLump(todayLump: todayLump)
                }
            }
            .task {
                settingsObj.sync()
                if HKHealthStore.isHealthDataAvailable() {
                    hkTrigger.toggle()
                }
                await dataStore.updateLump(todayLump: todayLump)
            }
            .healthDataAccessRequest(store: healthStore, shareTypes: writeTypes, readTypes: readTypes, trigger: hkTrigger) { _ in
                Task { await dataStore.updateLump(todayLump: todayLump) }
            }
        }
    }

    private func logWater(_ ml: Int) {
        Task {
            await dataStore.addWater(amount: ml, datetime: Date())
            confirm("Logged \(ml)ml", for: .water)
            await dataStore.updateLump(todayLump: todayLump)
        }
    }

    private func logCalories(_ amount: Int) {
        Task {
            // `??`'s right-hand operand is an autoclosure, which can't contain `await`,
            // so resolve the fallback meal in explicit steps instead.
            var meal = settingsObj.snacksUUID
            if meal == nil {
                meal = await dataStore.calorieActor.getMealUUIDbyName(name: "Snacks/Other")
            }
            await dataStore.addCalories(calories: amount, narrative: nil, date: Date(), meal: meal ?? UUID())
            confirm("Logged \(amount.formatted()) kcal", for: .calories)
            await dataStore.updateLump(todayLump: todayLump)
        }
    }

    private struct ConfirmationLabel: View {
            let text: String

            var body: some View {
                Label(text, systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.green)
                    .transition(.opacity)
            }
        }

        /// Success haptic plus a transient confirmation next to the control that was used,
        /// so logging is visibly acknowledged even on silent mode.
        @MainActor
        private func confirm(_ text: String, for target: LogTarget) {
            WKInterfaceDevice.current().play(.success)
            confirmGeneration += 1
            let generation = confirmGeneration
            withAnimation {
                switch target {
                case .calories: calConfirmation = text
                case .water: waterConfirmation = text
                }
            }
            Task {
                try? await Task.sleep(for: .seconds(2))
                guard generation == confirmGeneration else { return }
                withAnimation {
                    calConfirmation = nil
                    waterConfirmation = nil
                }
            }
        }
}

/// A simple digits-only entry pad — watchOS's TextFieldLink can only offer the full
/// system keyboard, so numeric fields get this instead.
struct WatchNumberPad: View {
    let prompt: String
    let onCommit: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var entry: String = ""

    private let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["⌫", "0", "OK"]]

    private func tap(_ key: String) {
        switch key {
        case "⌫":
            if !entry.isEmpty { entry.removeLast() }
        case "OK":
            if let value = Int(entry), value > 0 {
                WKInterfaceDevice.current().play(.click)
                onCommit(value)
            }
            dismiss()
        default:
            if entry.count < 4 { entry += key }
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(entry.isEmpty ? prompt : entry)
                .font(.headline)
                .foregroundStyle(entry.isEmpty ? .secondary : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                ForEach(rows, id: \.self) { row in
                    GridRow {
                        ForEach(row, id: \.self) { key in
                            Button {
                                tap(key)
                            } label: {
                                Text(key)
                                    .font(.system(.body, design: .rounded).weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 30)
                            }
                            .buttonStyle(.plain)
                            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                            .foregroundStyle(key == "OK" ? .green : .primary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 2)
    }
}

#Preview {
    ContentView()
}
