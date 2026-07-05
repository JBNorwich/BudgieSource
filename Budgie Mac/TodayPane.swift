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

struct TodayPane: View {
    @EnvironmentObject private var todayLump: TodayLump
    @State private var showAddFood = false
    @State private var showAddWater = false
    @State private var showDataView = false
    @State private var greeting = getBudgieGreeting()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                budgetSection

                if settingsObj.snapshotTimestamp != 0 {
                    if settingsObj.budgetSnapshotIsFresh {
                        GroupBox {
                            GaugeView()
                        } label: {
                            Label("Your target", systemImage: "gauge.with.needle")
                        }
                        .backgroundStyle(.regularMaterial)
                        .onTapGesture {
                            showDataView = true
                        }
                    }

                    GroupBox {
                        VStack {
                            TodayFoodList()
                        }.padding()
                    } label: {
                        Label("Eaten today", systemImage: "fork.knife")
                    }
                    .backgroundStyle(.regularMaterial)

                    waterTodaySection
                    
                    budgetFootnote
                }
            }
            .padding(28)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Image("Budgie")
                        .interpolation(.high)
                        .resizable()
                        .frame(maxWidth: 116,maxHeight: 100)
                    Text(greeting)
                    Spacer()
                }.offset(x: 0, y: 0)
            }
        }
        .navigationTitle("Today")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Spacer()
                Button("Add water", systemImage: "drop") { showAddWater = true }
                Button("Add food", systemImage: "plus") { showAddFood = true }
            }
        }
        .sheet(isPresented: $showAddFood) {
            MacAddFoodSheet(initialDate: Date()).environmentObject(todayLump)
        }
        .sheet(isPresented: $showAddWater) {
            MacAddWaterSheet(dateToAddOn: Date()).environmentObject(todayLump)
        }
        
        .sheet(isPresented: $showDataView)
        {
            VStack {
                HStack {
                    Text("Today in detail").font(.title2).bold()
                    Spacer()
                    Button("Close") { showDataView = false }
                }.padding()
                Divider()
                NewDataView().environmentObject(todayLump)
            }
        }
    }

    // MARK: Budget — three states: waiting / fresh (live blob) / stale (number only)

    @ViewBuilder private var budgetSection: some View {
        if settingsObj.snapshotTimestamp == 0 {
            waitingForPhone
        } else if settingsObj.budgetSnapshotIsFresh {
            VStack(spacing: 14) {
                MeterView(dummy: false)
                    .frame(width: 240, height: 240)

                if let date = settingsObj.budgetSnapshotDate,
                   Date().timeIntervalSince(date) > 30 * 60 {
                    Text("Synced from your iPhone at \(date.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
        } else {
            staleBudget
        }
    }

    private var waitingForPhone: some View {
        ContentUnavailableView {
            Label("Waiting for your iPhone", systemImage: "iphone.gen3")
        } description: {
            Text("Your daily budget is worked out on your iPhone from your activity. It'll appear here once Budgie Diet on your phone has synced with iCloud.")
        }
        .frame(maxWidth: 440)
        .padding(.vertical, 40)
    }

    private var staleBudget: some View {
        VStack(spacing: 8) {
            Text("Today's budget").font(.headline)
            Text(todayLump.totalBudget.formatted())
                .font(.system(size: 52, weight: .heavy))
                .contentTransition(.numericText())
            Text("kcal").foregroundStyle(.secondary)
            Text("You've logged \(todayLump.eatenCalories.formatted()) kcal so far today.")
                .font(.callout).foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder private var budgetFootnote: some View {
        if let date = settingsObj.budgetSnapshotDate {
            Label(settingsObj.budgetSnapshotIsFresh
                  ? "Your calories out, as well as any calories or water in from Apple Health, are based on data synced from your iPhone. This was last synced at \(date.formatted(date: .omitted, time: .shortened))."
                  : "Your iPhone was last synced at \(date.formatted(date: .abbreviated, time: .shortened)), so your budget is based on old calorie data. It'll refresh the next time Budgie Diet runs there.",
                  systemImage: "info.circle")
        }
    }

    private var waterTodaySection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(renderVolume(millilitres: todayLump.waterToday))
                    Spacer()
                    Text("of \(renderVolume(millilitres: todayLump.effectiveWaterGoal))")
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: todayLump.waterGoalDone)
            }
            .padding()
        } label: {
            Label("Water", systemImage: "drop.fill")
        }
        .backgroundStyle(.regularMaterial)
    }
}
