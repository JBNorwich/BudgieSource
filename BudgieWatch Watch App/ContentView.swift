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

struct ContentView: View {
    @StateObject var todayLump: TodayLump = TodayLump()
    @Environment(\.scenePhase) private var scenePhase
    @State private var hkTrigger = false
    @State private var quickCals: Int = 100

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    WatchMeter()
                        .environmentObject(todayLump)
                        .frame(maxHeight: 150)
                        .padding()
                        .onTapGesture {
                            Task {
                                await dataStore.updateLump(todayLump: todayLump)
                            }
                        }
                    VStack {
                        HStack {
                            Text("Your budget")
                                .font(.headline)
                            Spacer()
                        }
                        HStack {
                            Text("Total budget")
                            Spacer()
                            Text(todayLump.totalBudget.formatted())
                        }
                        HStack {
                            Text("Eaten today")
                            Spacer()
                            Text(todayLump.eatenCalories.formatted())
                        }
                        HStack {
                            Text(todayLump.totalBudgetRem > -1 ? "Left today" : "Over budget by")
                            Spacer()
                            Text(abs(todayLump.totalBudgetRem).formatted())
                        }
                        if todayLump.activeEstimated == true || todayLump.basalEstimated == true {
                            Spacer()
                            Label("Your calories out are estimated, so your budget isn't based on real activity.", systemImage: "info.circle")
                                .font(.caption)
                        }
                    }
                    Divider()
                    VStack {
                        HStack {
                            Text("Quick log")
                                .font(.headline)
                            Spacer()
                        }
                        HStack {
                            Button("250ml", systemImage: "drop.fill") { logWater(250) }
                            Button("500ml", systemImage: "drop.fill") { logWater(500) }
                        }
                        Stepper(value: $quickCals, in: 50...2000, step: 50) {
                            Text("\(quickCals.formatted()) kcal")
                        }
                        Button("Log calories", systemImage: "fork.knife") { logCalories() }
                    }
                    Divider()
                    Text("To see more, open Budgie Diet on your iPhone.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                        .padding()
                }
            }
            .navigationTitle("Your target")
            .padding()

            .onChange(of: scenePhase) {
                guard scenePhase == .active else {
                   return
                }
                Task {
                    await dataStore.updateLump(todayLump: todayLump)
                }
            }
            .task {
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
            await dataStore.updateLump(todayLump: todayLump)
        }
    }

    private func logCalories() {
        Task {
            // `??`'s right-hand operand is an autoclosure, which can't contain `await`,
            // so resolve the fallback meal in explicit steps instead.
            var meal = settingsObj.snacksUUID
            if meal == nil {
                meal = await dataStore.calorieActor.getMealUUIDbyName(name: "Snacks/Other")
            }
            await dataStore.addCalories(calories: quickCals, narrative: nil, date: Date(), meal: meal ?? UUID())
            await dataStore.updateLump(todayLump: todayLump)
        }
    }
}

#Preview {
    ContentView()
}
