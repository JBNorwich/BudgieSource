//
//  ChartView.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 22/08/2024.
//

import SwiftUI
import Charts

struct ChartPage: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject var chartDataStore = ChartData()
    @Binding var dataStore: HealthData
    @Binding var todayLump: TodayLump
    @State var startDate: Date = Date()
    @State var endDate: Date = Date()
    @State var loadingDone: Bool = false
    @State var dateChanged: Bool = false
    
    var body: some View {
        VStack {
            if loadingDone == true {
                VStack {
                    ChartDatePicker(startDate: $startDate, endDate: $endDate, dateChanged: $dateChanged)
                    
                    if chartDataStore.returnedChartData.count != 0 {
                        ChartView(chartData: $chartDataStore.returnedChartData)
                        ChartTableView(dataStore: $dataStore, todayLump: $todayLump, chartData: $chartDataStore.returnedChartData)
                    } else {
                        Label("No data was returned. Either you have no data in Health, or you didn't give Budgie Diet permissions to see your data.", systemImage: "exclamationmark.octagon")
                        Spacer()
                    }
                    
                }.padding()
                
                    .navigationTitle("History")
                    .toolbar {
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            Button("Refresh", systemImage: "arrow.clockwise") {
                                dateChanged = true
                            }
                        }
                    }
            } else {
                ProgressView(label: {
                    Text("Loading")
                        .font(.caption)
                        .foregroundColor(.secondary)
                })
                .progressViewStyle(.circular)
                .navigationTitle("History")
            }
        }
        .onChange(of: chartDataStore.dataUpdated)
        {
            if chartDataStore.dataUpdated == true {
                loadingDone = false
                chartDataStore.assembleChartData()
                loadingDone = true
                dateChanged = false
            }
        }
    
        .onChange(of: dateChanged, initial: false) {
            if dateChanged == true {
                chartDataStore.startDate = getStartOfDay(date: startDate)
                chartDataStore.endDate = getStartOfDay(date: endDate)
                loadingDone = false
                Task {
                    await chartDataStore.pokeForUpdate()
                }
            }
        }
        
        .onAppear() {
            loadingDone = false
            startDate = chartDataStore.startDate
            endDate = chartDataStore.endDate
            Task {
                await chartDataStore.pokeForUpdate()
            }
        }
    }
}

#Preview {
    struct Preview: View {
        @State var object = HealthData()
        @State var lump = TodayLump()
        
        var body: some View {
            ChartPage(dataStore: $object, todayLump: $lump)
        }
    }
    
    return Preview()
}
