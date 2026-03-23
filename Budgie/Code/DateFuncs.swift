//
//  DateFuncs.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 19/08/2024.
//

import Foundation

func getStartOfDay(date: Date) -> Date {
    let calendar = NSCalendar.current
    return calendar.startOfDay(for: date)
}

func getMidnightOnDayBefore(date: Date) -> Date {
    let calendar = NSCalendar.current
    return calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: date)!)
}

func getHalfHourBefore(date: Date) -> Date {
    let calendar = NSCalendar.current
    return calendar.date(byAdding: .minute, value: -30, to: date)!
}

func getMidnightOnDayAfter(date: Date) -> Date {
    let calendar = NSCalendar.current
    return calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: date)!)
}

func getWeekBeforeDate(date: Date) -> Date {
    let calendar = NSCalendar.current
    return calendar.startOfDay(for: calendar.date(byAdding: .day, value: -7, to: date)!)
}

func getWeekAfterDate(date: Date) -> Date {
    let calendar = NSCalendar.current
    return calendar.startOfDay(for: calendar.date(byAdding: .day, value: 7, to: date)!)
}

func minutesIntoDay() -> Int {
    let date = Date()
    let calendar = Calendar.current
    return (60 * calendar.component(.hour, from: date)) + calendar.component(.minute, from: date)
}

func getDayOfWeek() -> Int {
    let calendar = NSCalendar.current
    return calendar.dateComponents([.weekday], from: Date()).weekday!
}

func getHoursOfTime(date: Date) -> Int {
    let calendar = Calendar.current
    return calendar.component(.hour, from: date)
}

func getPercentOfDayDone() -> Double {
    return Double(minutesIntoDay()) / 1440
}

func weightForCertainty(input: Int) -> Int {
    var factor: Double = (Double(minutesIntoDay()) + 1) / 1200
    if factor > 1 {  factor = 1 }
    return Int(Double(input) * factor)
}

func weightLeftToEat(input: Int) -> Int {
    var factor = Double()
    
    let minsToWeightTo = Double(settingsObj.finalMealTime)
    let minsToWeightFrom: Double = 240
    let minsToWeight: Double = Double(minutesIntoDay() + 1) - minsToWeightFrom
    let diff = minsToWeightTo - minsToWeightFrom
    
    if minsToWeight < 0 {
        factor = 0
    } else {
        factor = minsToWeight/diff
    }
    if factor > 1 {  factor = 1 }
    return Int(Double(input) * factor)
}

func weightActiveProjection(input: Int, style: Int?, timeInput: Int?, actQuot: Double) -> Int {
    var doubleInput = Double(input)
    var usedActQuot: Double = actQuot
    var styleToUse: Int
    var time: Double
    if style != nil {
        styleToUse = style!
    } else {
        if settingsObj.differentWeights != true {
            styleToUse = settingsObj.weightingStyle
        } else {
            switch getDayOfWeek() {
                case 1: styleToUse = settingsObj.sunWeight
                case 2: styleToUse = settingsObj.monWeight
                case 3: styleToUse = settingsObj.tuesWeight
                case 4: styleToUse = settingsObj.wedsWeight
                case 5: styleToUse = settingsObj.thursWeight
                case 6: styleToUse = settingsObj.friWeight
                case 7: styleToUse = settingsObj.satWeight
                default: styleToUse = settingsObj.weightingStyle
            }
        }
    }
    
    if timeInput != nil {
        time = Double(timeInput!)
    } else {
        time = Double(minutesIntoDay())
    }
    
    var startTime: Double
    var stopTime: Double
    var weightTime: Double
    var weightFactor: Double
    var finalWeightFactor: Double
    
    switch styleToUse {
        case -1: doubleInput = 1 * doubleInput //forgiving
        case 0: doubleInput = 0.5 * doubleInput //default
        case 1: doubleInput = 0.25 * doubleInput //harsh
        case 3: doubleInput = 0.875 * doubleInput // old default
        default: print("Doing nothing")
    }
    
    switch styleToUse {
        case -2: usedActQuot = 1
        case -1: usedActQuot = 1 //forgiving
        case 3: usedActQuot = 1
        default: print("Doing nothing")
    }
    
    switch styleToUse {
        case -1: startTime = 240
        default: startTime = 0
    }
    switch styleToUse {
        case -1: stopTime = 1440
        case 0: stopTime = 1320
        case 1: stopTime = 1320
        case 3: stopTime = 1320
        default: stopTime = 1440
    }

    if time < startTime {
        weightTime = startTime
    } else {
        weightTime = time
    }
    
    switch styleToUse {
        case 2: weightFactor = 0
        default: weightFactor = weightTime/stopTime
    }
    
    switch styleToUse {
        case -2: finalWeightFactor = 1
        case -1: finalWeightFactor = 1 - pow(weightFactor, 5)
        case 0: finalWeightFactor = 1 - pow(weightFactor, 2)
        case 1: finalWeightFactor = 1 - weightFactor
        case 3: finalWeightFactor = 1 - pow(weightFactor, 2)
        default: finalWeightFactor = 0
    }
    
    let result = Int((finalWeightFactor * doubleInput) * usedActQuot)
    
    if result > 0 {
        return result
    } else {
        return 0
    }
}

func isAfterToday(date: Date) -> Bool
{
    if date > getMidnightOnDayAfter(date: Date()) {
        return true
    } else {
        return false
    }
}

func getCurrentTimeonDate(date: Date) -> Date {
    let calendar = Calendar.current
    let currentTime = Date()
    
    let hours = calendar.component(.hour, from: currentTime)
    let mins = calendar.component(.minute, from: currentTime)
    let seconds = calendar.component(.second, from: currentTime)
    
    let day = calendar.component(.day, from: date)
    let month = calendar.component(.month, from: date)
    let year = calendar.component(.year, from: date)
    
    let newDateComps = DateComponents(year: year, month: month, day: day, hour: hours, minute: mins, second: seconds)
    let newDate = calendar.date(from: newDateComps)
    return newDate!
}

extension Calendar {
    func numberOfDaysBetween(_ from: Date, and to: Date) -> Int {
        let fromDate = startOfDay(for: from) // <1>
        let toDate = startOfDay(for: to) // <2>
        let numberOfDays = dateComponents([.day], from: fromDate, to: toDate) // <3>
        
        return numberOfDays.day!
    }
}

func negate(value: Int) -> Int {
    return -value
}

func timeToMinsIntoDay(time: Date) -> Int {
    let calendar = Calendar.current
    let hour = calendar.component(.hour, from: time)
    let minute = calendar.component(.minute, from: time)
    return (hour * 60) + minute
}

func minsIntoDayIntoTime(mins: Int) -> Date {
    let hours = mins / 60
    let minutes = mins % 60
    var dateComponents = DateComponents()
    dateComponents.hour = hours
    dateComponents.minute = minutes
    return Calendar.current.date(from: dateComponents)!
}

func formatDuration(days: Int) -> String {
    if days < 7 {
        if days > 0 {
            return "about \(days) days"
        } else {
            return "not very long from now"
        }
    } else {
        var weeks: Int = 0
        let excess = days % 7
        if excess == 0 {
            weeks = days / 7
        } else {
            weeks = (days / 7) + 1
        }
        if weeks < 12 {
            return "about \(weeks) weeks"
        } else {
            if weeks > 52 {
                return "over a year"
            } else {
                if days % 30 != 0 {
                    let months = (days/30) + 1
                    return "about \(months) months"
                } else {
                    let months = (days/30)
                    return "about \(months) months"
                }
                
            }
        }
    }
}

func getDaysToLose(weight: Double, deficit: Int) -> Int {
    if weight == 0 || deficit == 0 {
        return 0
    } else {
        print("Weight: \(weight.formatted())")
        let calsPerKg: Double = 7700
        let calsToLose = weight * calsPerKg
        let result = Int(calsToLose) / deficit
        print("Days: \(result)")
        return result
    }
}

func roundDoubleWeight(input: Double) -> Double {
    return round(input * 10) / 10
}

func adjustDeficitPrediction(deficit: Int, factor: Double) -> Int {
    if deficit <= 0 {
        return 0
    } else {
        let doubleCalc = Double(deficit) * factor
        print ("Adjusted from \(deficit) to \(Int(doubleCalc).formatted())")
        return Int(doubleCalc)
    }
}

extension String {
    func capitalizingFirstLetter() -> String {
      return prefix(1).uppercased() + self.lowercased().dropFirst()
    }

    mutating func capitalizeFirstLetter() {
      self = self.capitalizingFirstLetter()
    }
}
