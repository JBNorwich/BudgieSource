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
    @State var blobColour: Color = .clear
    @State var pathColour: Color = .clear

    @State var displayedLTE = Int()
    @State var displayedTime = Double()
    var dummy: Bool
    
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

    var body: some View {
        
        ZStack {
            if dummy != true {
                Circle()
                    .fill(.shadow(.drop(color: .black, radius: 4)))
                    .fill(todayLump.getBlobColour())
                Circle()
                    .trim(from: 0, to: todayLump.progressToday)
                    .rotation(Angle(degrees: -90))
                    // GOES CLOCKWISE FROM EAST
                    .fill(.clear)
                    .stroke(todayLump.getPathColour().gradient, style:StrokeStyle(lineWidth: 28, lineCap: .round))
                    .animation(.easeInOut, value: todayLump.progressToday)
                    .shadow(radius: 10)
                    .shadow(radius: 5)
                    .sensoryFeedback(.increase, trigger: todayLump.progressToday)
                VStack {
                    Text(getNiceBudgetDisplay(leftToEat: todayLump.leftToEat))
                        .font(.headline)
                        .minimumScaleFactor(0.01)
                        .scaledToFill()
                        .contentMargins(50)
                        .foregroundColor(.white)
                    Text(todayLump.normalisedLTE)
                        .fontWeight(.heavy)
                        .font(.system(size:60))
                        .minimumScaleFactor(0.01)
                        .scaledToFill()
                        .contentMargins(50)
                        .contentTransition(.numericText())
                        .shadow(radius: 5)
                        .foregroundColor(.white)
                        .sensoryFeedback(.increase, trigger: todayLump.leftToEat)
                        .contentTransition(.numericText())
                }
            } else {
                Circle()
                    .fill(.shadow(.drop(color: .black, radius: 4)))
                    .fill(.teal.gradient)
                Circle()
                    .trim(from: 0, to: 0.6)
                    .rotation(Angle(degrees: -90))
                    // GOES CLOCKWISE FROM EAST
                    .fill(.clear)
                    .stroke(.green.gradient, style:StrokeStyle(lineWidth: 28, lineCap: .round))
                    .animation(.easeInOut, value: 0.6)
                    .shadow(radius: 10)
                    .shadow(radius: 5)
                VStack {
                    Text("Can eat now")
                        .font(.headline)
                        .minimumScaleFactor(0.01)
                        .scaledToFill()
                        .contentMargins(50)
                        .foregroundColor(.white)
                    Text("428")
                        .fontWeight(.heavy)
                        .font(.system(size:60))
                        .minimumScaleFactor(0.01)
                        .scaledToFill()
                        .contentMargins(50)
                        .contentTransition(.numericText())
                        .shadow(radius: 5)
                        .foregroundColor(.white)
                }
            }
        }
            
            .onChange(of: todayLump.progressTodayAsWholePercent) {
                withAnimation {
                    pathColour = todayLump.getPathColour()
                    displayedTime = getPercentOfDayDone()
                }
            }
        
            .onChange(of: todayLump.leftToEat) {
                withAnimation {
                    displayedTime = getPercentOfDayDone()
                    pathColour = todayLump.getPathColour()
                }
            }
        
        
            .onAppear() {
                displayedTime = getPercentOfDayDone()
                withAnimation {
                    pathColour = todayLump.getPathColour()
                }
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
