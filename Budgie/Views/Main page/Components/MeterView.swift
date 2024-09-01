//
//  MeterView.swift
//  Budgie
//
//  Created by Joe Baldwin on 20/08/2024.
//

import SwiftUI

struct MeterView: View {
    @Binding var todayLump: TodayLump
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
            MeterView(todayLump:$dummyData, dummy: false)
        }
    }
    
    return Preview()
}
