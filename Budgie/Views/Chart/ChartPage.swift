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
import Charts

struct ChartPage: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject var chartDataStore = ChartData()
    @EnvironmentObject var todayLump: TodayLump
    @State var startDate: Date = Date()
    @State var endDate: Date = Date()
    @State var loadingDone: Bool = false
    @State var dateChanged: Bool = false
    
    var body: some View {
        VStack {
            if loadingDone == true {
                VStack {
                    ChartDatePicker(startDate: $startDate, endDate: $endDate, dateChanged: $dateChanged)
                    
                    if !chartDataStore.returnedChartData.isEmpty {
                        ChartView(chartData: $chartDataStore.returnedChartData)
                        ChartTableView(chartData: chartDataStore.returnedChartData).environmentObject(todayLump)
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
        @State var lump = TodayLump()
        
        var body: some View {
            ChartPage().environmentObject(lump)
        }
    }
    
    return Preview()
}
