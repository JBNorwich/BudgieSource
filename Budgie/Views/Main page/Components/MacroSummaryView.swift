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

/// The macro readout above the food list on BudgetView: protein, fat and carbs eaten today. Each macro shows a ring filling toward its goal (overflowing past full when exceeded), or just the day's total where no goal is set. Purely quantitative — no target appears where none was chosen, and going over a goal is shown neutrally, never flagged.
struct MacroSummaryView: View {
    @EnvironmentObject var dataLump: TodayLump

    private var goals: (protein: Int?, fat: Int?, carbs: Int?) {
        settingsObj.macroGoalGrams(budget: dataLump.totalBudget)
    }

    var body: some View {
        let g = goals
        HStack(alignment: .top, spacing: 12) {
            MacroCell(title: "Protein", eaten: dataLump.eatenProtein, goal: g.protein, colour: .pink)
            MacroCell(title: "Carbs",   eaten: dataLump.eatenCarbs,   goal: g.carbs,   colour: .green)
            MacroCell(title: "Fat",     eaten: dataLump.eatenFat,     goal: g.fat,     colour: .yellow)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
    }
}

private struct MacroCell: View {
    let title: String
    let eaten: Int
    let goal: Int?
    let colour: Color

    private var fraction: Double {
        guard let goal, goal > 0 else { return 0 }
        return Double(eaten) / Double(goal)
    }

    var body: some View {
        VStack(spacing: 6) {
            if let goal {
                ZStack {
                    Circle()
                        .stroke(colour.opacity(0.2), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: min(fraction, 1))
                        .stroke(colour, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    if fraction > 1 {
                        // Overflow: a second, dimmer lap so passing the goal reads clearly but calmly.
                        Circle()
                            .trim(from: 0, to: min(fraction - 1, 1))
                            .stroke(colour.opacity(0.55), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                }
                .frame(width: 60, height: 60)
                .animation(.default, value: fraction)

                Text(title).font(.caption).foregroundStyle(.secondary)
                Text("\(eaten) / \(goal) g")
                    .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
            } else {
                Circle().fill(colour).frame(width: 10, height: 10).padding(.top, 6)
                Text("\(eaten) g").font(.title3).bold().monospacedDigit()
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
