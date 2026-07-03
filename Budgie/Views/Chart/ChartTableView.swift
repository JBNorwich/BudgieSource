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
                ChartTableRow(dataLump: dataLump)
                    .onTapGesture {
                        selDate = dataLump.date
                        openingFoodHub = true
                    }
                
                Divider()
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

struct ChartTableRow: View {
    private static let dayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        // Locale-aware day+month (UK "03/07", US "7/3") instead of hardcoded dd/MM.
        formatter.setLocalizedDateFormatFromTemplate("dM")
        return formatter
    }()

    var dataLump: ChartDataLump
    var maxHeight: CGFloat = 50
    
    private var formDate: String {
        Self.dayMonthFormatter.string(from: dataLump.date)
    }

    var body: some View {
        let assessment = assessDeficit(desired: settingsObj.desiredDeficit, actual: dataLump.deficit)

        VStack {
            HStack {
                // Left: day of week + date
                VStack {
                    Text(getFullDayOfWeek(date: dataLump.date))
                    Text(formDate)
                        .font(.title)
                        .bold()
                }.frame(minWidth: 70)

                // Middle: cals in / out / deficit (card optional)
                VStack(spacing: 2) {
                    HStack {
                        Text("CALS IN").font(.caption)
                        Spacer()
                        Text(dataLump.eatenCals.formatted()).font(.caption)
                    }
                    HStack {
                        Text("CALS OUT").font(.caption)
                        Spacer()
                        Text(dataLump.totalCals.formatted()).font(.caption)
                    }
                    Divider()
                    HStack {
                        Text(dataLump.deficit < 0 ? "SURPLUS" : "DEFICIT")
                            .font(.caption)
                            .fontWeight(.bold)
                        Spacer()
                        Text((-dataLump.deficit).formatted())
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                }
                .padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 5).fill(.background))

                // Right: assessment narrative + off-target figure
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
                        Text(abs(assessment.offTarget).formatted())
                            .font(.title)
                            .minimumScaleFactor(0.1)
                            .scaledToFit()
                    }
                }.frame(minWidth: 105, maxWidth: 105)
            }.frame(maxHeight: maxHeight)
        }
    }
}
