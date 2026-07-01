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

struct DeficitAssessment {
    var offTarget: Int = 0
    var narrative: String = ""
}

func sortChartData(data: [ChartDataLump]) -> [ChartDataLump] {
    return data.sorted { $0.date > $1.date }
}

func assessDeficit(desired: Int, actual: Int) -> DeficitAssessment {
    var returnStruct = DeficitAssessment()
    let diff = actual - desired
    returnStruct.offTarget = diff
    
    if diff == 0 {
        returnStruct.narrative = "ON TARGET"
    } else if diff > 0 {
        returnStruct.narrative = settingsObj.surplusMode ? "UNDER TARGET" : "UNDER BUDGET"
    } else {
        returnStruct.narrative = settingsObj.surplusMode ? "ABOVE TARGET" : "OVER BUDGET"
    }
    
    return returnStruct
}

struct ChartTableView: View {
    @EnvironmentObject var todayLump: TodayLump
    @State var chartData: [ChartDataLump]
    @State var openingFoodHub: Bool = false
    @State var selDate: Date = Date()
    
    var body: some View {
        ScrollView {
            ForEach(sortChartData(data: chartData)) { dataLump in
                ChartTableRow(dataLump: dataLump).environmentObject(todayLump)
                    .onTapGesture {
                        selDate = dataLump.date
                        openingFoodHub = true
                    }
            }
            if settingsObj.whalesEverywhere == true {
                VStack {
                    Spacer()
                    VStack {
                        Text("🐋 " + (whaleSalutations.randomElement() ?? "Whoops, I'm a whale."))
                            .padding()
                    }
                } .frame(minHeight: 100)
            }
        }
        
        .navigationDestination(isPresented: $openingFoodHub)
        {
            FoodHub(curDate: selDate).environmentObject(todayLump)
        }
    }
}

func getFullDayOfWeek(date: Date) -> String {
    let index = Calendar.current.component(.weekday, from: date)
    return Calendar.current.weekdaySymbols[index - 1]
}

func negate(number: Int) -> Int {
    return -number
}

struct ChartTableRow: View {
    private static let dayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM"
        return formatter
    }()
    
    var dataLump: ChartDataLump
    @EnvironmentObject var todayLump: TodayLump
    
    private var formDate: String {
        Self.dayMonthFormatter.string(from: dataLump.date)
    }

    var body: some View {
        let assessment = assessDeficit(desired: settingsObj.desiredDeficit, actual: dataLump.deficit)
        
        VStack {
            HStack {
                VStack {
                    Text(getFullDayOfWeek(date: dataLump.date))
                    Text(formDate)
                        .font(.title)
                        .fontWeight(/*@START_MENU_TOKEN@*/.bold/*@END_MENU_TOKEN@*/)
                }.frame(minWidth: 70)
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .foregroundStyle(.background)
                        .overlay {
                            VStack {
                                HStack {
                                    Text("CALS IN")
                                        .font(.caption)
                                    Spacer()
                                    Text(dataLump.eatenCals.formatted())
                                        .font(.caption)
                                }
                                HStack {
                                    Text("CALS OUT")
                                        .font(.caption)
                                    Spacer()
                                    Text(dataLump.totalCals.formatted())
                                        .font(.caption)
                                }
                                Divider()
                                HStack {
                                    
                                    if dataLump.deficit < 0 {
                                        Text("SURPLUS")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                    } else {
                                        Text("DEFICIT")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                    }
                                    
                                    Spacer()
                                    Text(negate(number: dataLump.deficit).formatted())
                                        .font(.caption)
                                        .fontWeight(.bold)
                                }
                            }.minimumScaleFactor(0.1)
                                .scaledToFill()
                                .padding()
                        }
                }
                VStack {
                    Text(assessment.narrative)
                        .font(.caption)
                        .minimumScaleFactor(0.1)
                        .scaledToFit()
                    Spacer()
                    HStack {
                        if assessment.offTarget == 0 {
                            Image(systemName: "arrow.right")
                        } else if assessment.offTarget < 0 {
                            Image(systemName: "arrow.up")
                        } else {
                            Image(systemName: "arrow.down")
                        }
                        Spacer()
                        if assessment.offTarget < 0 {
                            Text((-assessment.offTarget).formatted())
                                .font(.title)
                                .minimumScaleFactor(0.1)
                                .scaledToFit()
                        } else {
                            Text(assessment.offTarget.formatted())
                                .font(.title)
                                .minimumScaleFactor(0.1)
                                .scaledToFit()
                        }
                    }
                }.frame(minWidth: 105, maxWidth: 105)
            }
    }
        Divider()
    }
}

#Preview {
    struct Preview: View {
        @State var dummyData: [ChartDataLump] = fetchDummyData()
        @State var todayLump = TodayLump()
        
        var body: some View {
            ChartTableView(chartData: dummyData).environmentObject(todayLump)
        }
    }
    
    return Preview()
}
