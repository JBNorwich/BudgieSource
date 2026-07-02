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

func deficitMagnitude(_ deficit: Int) -> Int { max(deficit, 0) }
func surplusMagnitude(_ surplus: Int) -> Int { max(-surplus, 0) }

func graphTargetNumber() -> Int
{
    if settingsObj.desiredDeficit > 0
    {
        return settingsObj.desiredDeficit
    } else if settingsObj.desiredDeficit < 0 {
        return -settingsObj.desiredDeficit
    } else {
        return 0
    }
}

func getSurpDef() -> String {
    if settingsObj.surplusMode == true{
        return "Surplus"
    } else {
        return "Deficit"
    }
}

func getDerpSef() -> String {
    if settingsObj.surplusMode == true{
        return "Deficit"
    } else {
        return "Surplus"
    }
}

struct ChartView: View {
    @Binding var chartData: [ChartDataLump]
    var goodString: String { settingsObj.surplusMode ? "Surplus" : "Deficit" }
    var badString: String { settingsObj.surplusMode ? "Deficit" : "Surplus" }
    var targString: String { "TARGET " + goodString.uppercased() }
    var targDeficit: Int { abs(settingsObj.desiredDeficit) }
    
    var body: some View {
        Chart(chartData) {
            LineMark(
                x: .value("Date", $0.date),
                y: .value("Calories in", $0.eatenCals),
                series: .value("Calories in", "A"))
                .foregroundStyle(.red)
            LineMark(
                x: .value("Date", $0.date),
                y: .value("Calories out", $0.totalCals),
                series: .value("Calories out", "B"))
                .foregroundStyle(.green)
            if settingsObj.surplusMode != true {
                BarMark(x: .value("Date", $0.date), y: .value("Deficit", deficitMagnitude($0.deficit))).foregroundStyle(.teal)
                BarMark(x: .value("Date", $0.date), y: .value("Surplus", surplusMagnitude($0.deficit))).foregroundStyle(.orange)
            } else {
                BarMark(x: .value("Date", $0.date), y: .value("Surplus", surplusMagnitude($0.deficit))).foregroundStyle(.teal)
                BarMark(x: .value("Date", $0.date), y: .value("Deficit", deficitMagnitude($0.deficit))).foregroundStyle(.orange)
            }
            if (targDeficit != 0) {
                RuleMark(
                    y: .value("Average deficit", targDeficit))
                .lineStyle(.init(dash: [5]))
                .foregroundStyle(.blue)
                .annotation(position: .topTrailing, alignment: .trailing, overflowResolution: AnnotationOverflowResolution(x: .fit(to: .plot), y: .fit)) {
                    Text(targString)
                        .foregroundStyle(.blue)
                        .font(.caption)
                }
            }
        }.frame(maxHeight: 300)
            .chartForegroundStyleScale(["Calories in": Color.red, "Calories out": Color.green, goodString: Color.teal, badString: Color.orange])
            .chartLegend(.visible)
            .chartLegend(position: .bottom, alignment: .center)
            .contentTransition(.interpolate)
    }
}
