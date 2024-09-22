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
    @ObservedObject var connectivity = Connectivity()
    @Environment(\.scenePhase) private var scenePhase
    
//    init() {
////        Connectivity.shared.$settings
////            .dropFirst()
////            .receive(on: DispatchQueue.main)
////            .map { dict in
////                let uds = UserDefaults(suiteName: "group.JoeBaldwin.Budgie")
////                for (key, value) in dict {
////                    uds?.setValue(value, forKey: key)
////                }
////            }
//    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    WatchMeter(todayLump: $todayLump)
                        .frame(maxHeight: 150)
                        .padding()
                        .onTapGesture {
                            dataUpdated = true
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
            
            .onChange(of: dataUpdated, initial: true) {
                Task {
                    todayLump = await dataStore.produceTodayObject()
                }
            }
            
            .onChange(of: connectivity.updated) {
                dataUpdated = true
            }
            
            .onChange(of: scenePhase) {
                guard scenePhase == .active else {
                   return
                }
                
                dataUpdated = true
            }
        }
    }
}

#Preview {
    ContentView()
}
