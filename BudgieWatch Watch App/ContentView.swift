//
//  ContentView.swift
//  BudgieWatch Watch App
//
//  Created by Joe Baldwin on 01/09/2024.
//

import SwiftUI

struct ContentView: View {
    @State var dataStore: HealthData = HealthData()
    @State var todayLump: TodayLump = TodayLump()
    @State var dataUpdated: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    WatchMeter(todayLump: $todayLump)
                        .frame(maxHeight: 150)
                        .padding()
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
                    Text("To see more, open Budgie on your iPhone.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                        .padding()
                }
            }
            .navigationTitle("Your target")
            .padding()
            
            .onChange(of: dataUpdated, initial: true) {
                Task {
                    todayLump = await dataStore.produceTodayObject()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
