//
//  WatchMeter.swift
//  BudgieWatch Watch App
//
//  Created by Joe Baldwin on 01/09/2024.
//

import SwiftUI

struct WatchMeter: View {
    @Binding var todayLump: TodayLump
    
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
