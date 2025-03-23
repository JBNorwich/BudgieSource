//
//  ContentView.swift
//  BudgieWatch Watch App
//
//  Created by Joe Baldwin on 01/09/2024.
//

import SwiftUI

struct ContentView: View {
    @StateObject var todayLump: TodayLump = TodayLump()
    @ObservedObject var connectivity = Connectivity()
    @Environment(\.scenePhase) private var scenePhase
    
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
                            Text("Left today")
                            Spacer()
                            Text(todayLump.totalBudgetRem.formatted())
                        }
                        if todayLump.activeEstimated == true || todayLump.basalEstimated == true {
                            Spacer()
                            Label("Your calories out are estimated, so your budget isn't based on real activity.", systemImage: "info.circle")
                                .font(.caption)
                        }
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
            
            .onChange(of: connectivity.updated) {
                Task {
                    await dataStore.updateLump(todayLump: todayLump)
                }
            }
            
            .onChange(of: scenePhase) {
                guard scenePhase == .active else {
                   return
                }
                Task {
                    await dataStore.updateLump(todayLump: todayLump)
                }
            }
            .task {
                if settingsObj.manualMode != true {
                    dataStore.setUpObserverQueries(todayLump: todayLump)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
