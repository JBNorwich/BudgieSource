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

import Foundation
import SwiftUI

func getActivityNarrative(activityLevel: Double) -> String {
    switch activityLevel {
        
    case 0.375: return "You exercise a couple of days a week, or very lightly."
    case 0.55: return "You exercise 3-5 days a week."
    case 0.725: return "You are very active, and exercise 6-7 days a week."
    case 0.9: return "You have a very active and physical job, and burn a lot of calories every day."
    default: return "You do little to no exercise."
    }
}


// creates dummy data for the chart
func fetchDummyData() -> [ChartDataLump] {
    var curDate = Date()
    var dummyData: [ChartDataLump] = []
    let dummyData1 = ChartDataLump()
    //500 deficit - on target
    dummyData1.date = curDate
    dummyData1.eatenCals = 2300
    dummyData1.basalCals = 2000
    dummyData1.activeCals = 800
    //dummyData1.totalCals = 2800
    dummyData.append(dummyData1)
    curDate = getMidnightOnDayBefore(date: curDate)
    //nil deficit - 500 over target
    let dummyData2 = ChartDataLump()
    dummyData2.date = curDate
    dummyData2.eatenCals = 1900
    dummyData2.basalCals = 1500
    dummyData2.activeCals = 400
    //dummyData2.totalCals = 1900
    dummyData.append(dummyData2)
    curDate = getMidnightOnDayBefore(date: curDate)
    //500 surplus - 1000 over target
    let dummyData3 = ChartDataLump()
    dummyData3.date = curDate
    dummyData3.eatenCals = 2600
    dummyData3.basalCals = 2000
    dummyData3.activeCals = 100
    //dummyData3.totalCals = 2100
    dummyData.append(dummyData3)
    curDate = getMidnightOnDayBefore(date: curDate)
    // 1000 deficit - 500 below target
    let dummyData4 = ChartDataLump()
    dummyData4.date = curDate
    dummyData4.eatenCals = 1500
    dummyData4.basalCals = 2100
    dummyData4.activeCals = 400
    //dummyData4.totalCals = 2500
    dummyData.append(dummyData4)
    return dummyData
}

func calcBMR(height: Int, weight: Int, age: Int, sex: Int)-> Int {
    var calculated = Double()
    let doubleWeight = Double(weight)
    let doubleHeight = Double(height)
    let doubleAge = Double(age)
    
    if sex == 1 {
        //male
        calculated = 88.362 + (13.397 * doubleWeight) + (4.799 * doubleHeight) - (5.677 * doubleAge)
    } else {
        //female or nothing specified - use sensible default
        calculated = 447.593 + (9.247 * doubleWeight) + (3.098 * doubleHeight) - (4.330 * doubleAge)
    }
    
    return Int(calculated)
}

func getBudgieGreeting() -> String {
    let greetingArray = ["Hi.", "Hello.", "Cheep.", "Tweet.", "Chirp.", "Aah! You found me!", "...moo?"]
    
    return greetingArray.randomElement()!
}

enum weightUnits: Int {
    case kilograms = 0
    case pounds = 1
    case stonepounds = 2
}

struct StonePounds {
    init(kilos: Double) {
        self.kilos = kilos
    }

    init(stones: Int, pounds: Int) {
        self.kilos = Double((stones * 14) + pounds) * 0.454
    }
    
    var kilos: Double
    
    var totalPounds: Int {
        get { Int((kilos / 0.454).rounded()) }
        set { kilos = Double(newValue) * 0.454 }
    }
    
    var stones: Int {
        get { totalPounds / 14 }
        set { totalPounds = (newValue * 14) + pounds }
    }
    
    var pounds: Int {
        get { totalPounds % 14 }
        set { totalPounds = (stones * 14) + newValue }
    }
    
    var string: String {
        switch (stones, pounds) {
        case (0, 0):
            return "0lb"
        case (_, 0):
            return "\(stones.formatted())st"
        case (0, _):
            return "\(pounds.formatted())lb"
        default:
            return "\(stones.formatted())st \(pounds.formatted())lb"
        }
    }
}


func renderWeight(kilos: Double, outputUnit: weightUnits? = nil, includeSuffix: Bool? = true) -> String {
    let usedOutputUnit: weightUnits = outputUnit ?? weightUnits(rawValue: settingsObj.weightDisplayUnit)!
    var returnString: String = ""
    
    switch usedOutputUnit {
        case .kilograms: returnString = roundDoubleWeight(input: kilos).formatted()
        case .pounds: returnString = roundDoubleWeight(input: kilos / 0.454).formatted()
        case .stonepounds: returnString = StonePounds(kilos: kilos).string // stonepounds doesn't make sense without units
    }
    
    if includeSuffix == true {
        switch usedOutputUnit {
            case .kilograms: returnString += "kg"
            case .pounds: returnString += "lbs"
            case .stonepounds: break
        }
    }
    
    return returnString
}
