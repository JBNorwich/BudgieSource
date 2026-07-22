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

struct MeterView: View {
    @EnvironmentObject var todayLump: TodayLump
    var dummy: Bool = false
    
    private struct BudgetRing: View {
        let blobColour: Color
        let pathColour: Color
        let progress: Double
        let label: String
        let value: String

        var body: some View {
            ZStack {
                Circle()
                    .fill(blobColour.shadow(.drop(color: .black, radius: 4)))
                Circle()
                    .trim(from: 0, to: progress)
                    .rotation(.degrees(-90))
                    .stroke(pathColour.gradient, style: StrokeStyle(lineWidth: 28, lineCap: .round))
                    .animation(.easeInOut, value: progress)
                    .shadow(radius: 10)
                VStack {
                    Text(label)
                        .font(.headline)
                        .minimumScaleFactor(0.01)
                    Text(value)
                        .fontWeight(.heavy)
                        .font(.system(size: 60))
                        .minimumScaleFactor(0.01)
                        .contentTransition(.numericText())
                        .shadow(radius: 5)
                }
                .foregroundColor(.white)
                .contentMargins(50)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue("\(value) calories")
        }
    }

    var body: some View {
        if dummy {
                BudgetRing(blobColour: .teal, pathColour: .green, progress: 0.6,
                           label: "Can eat now", value: "428")
        } else {
                BudgetRing(blobColour: budgetBlobColour(canEatNow: todayLump.canEatNow),
                           pathColour: budgetPathColour(diff: todayLump.progressAgainstTarget, budget: todayLump.totalBudget, projectedBasal: todayLump.projectedBasal),
                           progress: todayLump.progressToday,
                           label: budgetStatusLabel(leftToEat: todayLump.canEatNow),
                           value: abs(todayLump.canEatNow).formatted())
                    .sensoryFeedback(.increase, trigger: todayLump.progressToday)
                    .sensoryFeedback(trigger: todayLump.canEatNow) { old, new in new < old ? .decrease : .increase }
                    .animation(.easeInOut, value: todayLump.canEatNow)
        }
    }
}

#Preview {
    struct Preview: View {
        @State var dummyData = TodayLump()
        
        var body: some View {
            MeterView(dummy: false).environmentObject(dummyData)
        }
    }
    
    return Preview()
}
