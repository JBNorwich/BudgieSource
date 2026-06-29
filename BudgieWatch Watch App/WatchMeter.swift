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
    
    func getNiceBudgetDisplay(leftToEat: Int) -> String {
        var outputString = String()
        
        if settingsObj.surplusMode == true {
            if leftToEat > -1
            {
                outputString = "Need to eat"
            } else {
                outputString = "Overeaten by"
            }
        } else {
            if leftToEat > -1
            {
                outputString = "Can eat now"
            } else {
                outputString = "Over target by"
            }
        }
        return outputString
    }
    
    func getBlobColour(input: Int) -> Color
    {
        var returnColor: Color = .teal
        if input < -49
        {
            switch settingsObj.surplusMode {
            case true: returnColor = .green
            case false : returnColor = .red
            }
        } else if input < 50 {
            switch settingsObj.surplusMode {
            case true: returnColor = .red
            case false: returnColor = .green
            }
        }
        return returnColor
    }
    
    func getPathColour() -> Color
    {
        let reallyGoodColor = (Color.blue)
        let goodColour = Color(.green)
        let okColour = Color(.yellow)
        let badColour = Color(.yellow)
        
        let diff = todayLump.progressToday / getPercentOfDayDone()
        
        if diff < 0.25 {
            return reallyGoodColor
        } else if diff < 1.05 {
            return goodColour
        } else if diff < 1.20 {
            if (diff - 1) * Double(todayLump.totalBudget) < Double(todayLump.projectedBasal) {
                return goodColour
            } else {
                return okColour
            }
        } else {
            return badColour
        }
    }

    var body: some View {
        ZStack {
                Circle()
                    .fill(.shadow(.drop(color: .black, radius: 4)))
                    .fill(getBlobColour(input: todayLump.leftToEat))
                Circle()
                    .trim(from: 0, to: todayLump.progressToday)
                    .rotation(Angle(degrees: -90))
                    // GOES CLOCKWISE FROM EAST
                    .fill(.clear)
                    .stroke(getPathColour().gradient, style:StrokeStyle(lineWidth: 10, lineCap: .round))
                    .shadow(radius: 10)
                    .shadow(radius: 5)
                VStack {
                    Text(getNiceBudgetDisplay(leftToEat: todayLump.leftToEat))
                        .font(.headline)
                        .minimumScaleFactor(0.01)
                        .scaledToFill()
                        .contentMargins(50)
                        .foregroundColor(.white)
                    Text(todayLump.leftToEat.formatted())
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
