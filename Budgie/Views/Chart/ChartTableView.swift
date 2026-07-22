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
    /// Pre-sorted (newest first) by the caller — a plain property so the view always reflects the
    /// latest data on re-render, rather than a `@State` snapshot frozen at first `init`.
    var chartData: [ChartDataLump]
    @State var openingFoodHub: Bool = false
    @State var selDate: Date = Date()

    var body: some View {
        MetricHistoryList(rows: chartData) { dataLump in
            ChartTableRow(dataLump: dataLump)
                .onTapGesture {
                    selDate = dataLump.date
                    openingFoodHub = true
                }
        }
        .navigationDestination(isPresented: $openingFoodHub) {
            FoodHub(curDate: selDate).environmentObject(todayLump)
        }
    }
}

/// Reverse-chronological daily readout beneath a chart — the `ScrollView`/whale-easter-egg wrapper
/// shared by every chart tab's history list (calories, macros, water), whose rows (built on
/// `MetricRowLayout` below) are supplied by the caller.
struct MetricHistoryList<Row: Identifiable, RowContent: View>: View {
    var rows: [Row]
    @ViewBuilder var rowContent: (Row) -> RowContent

    var body: some View {
        ScrollView {
            ForEach(rows) { row in
                rowContent(row)
                Divider()
            }
            if settingsObj.whalesEverywhere == true {
                VStack {
                    Spacer()
                    Text("🐋 " + (whaleSalutations.randomElement() ?? "Whoops, I'm a whale."))
                        .padding()
                }.frame(minHeight: 100)
            }
        }
    }
}

func getFullDayOfWeek(date: Date) -> String {
    let index = Calendar.current.component(.weekday, from: date)
    return Calendar.current.weekdaySymbols[index - 1]
}

/// Locale-aware day+month (UK "03/07", US "7/3") — shared by every chart tab's history row, so a
/// date on the weight/macro/water lists formats identically to one on the calorie table.
let dayMonthFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.setLocalizedDateFormatFromTemplate("dM")
    return formatter
}()

/// Shared three-column row shape under every chart tab's history list: day/date on the left, a
/// "stats card" in the middle, and a headline figure on the right. `ChartTableRow` (calories) is
/// itself built on this, so every tab's list reads as one consistent design rather than four
/// independently-styled ones.
struct MetricRowLayout<Middle: View, Right: View>: View {
    var date: Date
    var maxHeight: CGFloat = 50
    @ViewBuilder var middle: Middle
    @ViewBuilder var right: Right

    var body: some View {
        HStack {
            // Left: day of week + date
            VStack {
                Text(getFullDayOfWeek(date: date))
                Text(dayMonthFormatter.string(from: date))
                    .font(.title)
                    .bold()
            }.frame(minWidth: 70)

            // Middle: a card of supporting figures
            middle
                .padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 5).fill(.background))

            // Right: the headline figure for this row
            right
                .frame(minWidth: 105, maxWidth: 105)
        }.frame(maxHeight: maxHeight)
    }
}

struct ChartTableRow: View {
    var dataLump: ChartDataLump
    var maxHeight: CGFloat = 50

    var body: some View {
        let assessment = assessDeficit(desired: settingsObj.desiredDeficit, actual: dataLump.deficit)

        MetricRowLayout(date: dataLump.date, maxHeight: maxHeight) {
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
                    Text(abs(dataLump.deficit).formatted())
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }
        } right: {
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
            }
        }
    }
}
