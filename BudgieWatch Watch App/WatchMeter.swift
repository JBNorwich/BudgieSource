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

struct WatchMeter: View {
    @EnvironmentObject var todayLump: TodayLump

    var body: some View {
        let pace = getPercentOfDayDone()
        let diff = pace > 0 ? todayLump.progressToday / pace : 0
        
        ZStack {
                Circle()
                    .fill(.shadow(.drop(color: .black, radius: 4)))
                    .fill(budgetBlobColour(canEatNow: todayLump.canEatNow))
                Circle()
                    .trim(from: 0, to: todayLump.progressToday)
                    .rotation(Angle(degrees: -90))
                    // GOES CLOCKWISE FROM EAST
                    .fill(.clear)
                    .stroke(budgetPathColour(diff: diff, budget: todayLump.totalBudget, projectedBasal: todayLump.projectedBasal))
                    .shadow(radius: 10)
                    .shadow(radius: 5)
                VStack {
                    Text(budgetStatusLabel(leftToEat: todayLump.canEatNow))
                        .font(.headline)
                        .minimumScaleFactor(0.01)
                        .scaledToFill()
                        .contentMargins(50)
                        .foregroundColor(.white)
                    Text(todayLump.canEatNow.formatted())
                        .fontWeight(.heavy)
                        .font(.system(size:40))
                        .minimumScaleFactor(0.01)
                        .scaledToFill()
                        .contentMargins(50)
                        .contentTransition(.numericText())
                        .shadow(radius: 5)
                        .foregroundColor(.white)
                }
            }
        }
}

//#Preview {
//    WatchMeter()
//}
