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

// This file contains various functions which are used to simplify date handling across Budgie Diet, rather than calling
// the relevant built in Swift functions over and over again, and to make the intent clearer. it also contains functions
// relating to the weighting of various bits of the user's budget.

// For purposes relating to UI, where no time is shown, a date is treated as midnight on that date.

/// Returns the start of the day for the date passed. Simple wrapper for calendar.startOfDay.
func getStartOfDay(date: Date) -> Date {
    let calendar = NSCalendar.current
    return calendar.startOfDay(for: date)
}

/// Returns midnight on the day before the date passed. For example, if you passed this function 19:02 on the 29th June, this would return 00:00 on the 28th June.
func getMidnightOnDayBefore(date: Date) -> Date {
    let calendar = NSCalendar.current
    return calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: date)!)
}

/// Returns half an hour before the Date() passed.
func getHalfHourBefore(date: Date) -> Date {
    let calendar = NSCalendar.current
    return calendar.date(byAdding: .minute, value: -30, to: date)!
}

/// Returns midnight on the day after the date passed. For example, if you passed this function 19:02 on the 29th June, it would return 00:00 on the 30th June.
func getMidnightOnDayAfter(date: Date) -> Date {
    let calendar = NSCalendar.current
    return calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: date)!)
}

/// Returns midnight on the date 7 days before the one passed. For example, if you passed this function 19:02 on the 29th June, it would return 00:00 on the 22nd June.
func getWeekBeforeDate(date: Date) -> Date {
    let calendar = NSCalendar.current
    return calendar.startOfDay(for: calendar.date(byAdding: .day, value: -7, to: date)!)
}

/// Returns midnight on the date 7 days after the one passed. For example, if you passed this function 19:02 on the 29th June, it would return 00:00 on the 6th July.
func getWeekAfterDate(date: Date) -> Date {
    let calendar = NSCalendar.current
    return calendar.startOfDay(for: calendar.date(byAdding: .day, value: 7, to: date)!)
}

/// Returns the number of minutes that have passed in the current day. Will return 0 at midnight.
func minutesIntoDay() -> Int {
    let date = Date()
    let calendar = Calendar.current
    return (60 * calendar.component(.hour, from: date)) + calendar.component(.minute, from: date)
}

/// Returns the day of the week in Int format.
func getDayOfWeek() -> Int {
    let calendar = NSCalendar.current
    return calendar.dateComponents([.weekday], from: Date()).weekday!
}

/// Returns the hour number of the current time. For example, if passed 19:02 on the 29th June, would return 19.
func getHoursOfTime(date: Date) -> Int {
    let calendar = Calendar.current
    return calendar.component(.hour, from: date)
}

/// Returns a simple Double() percentage of the minutes out of the 1,440 that there are in a day.
func getPercentOfDayDone() -> Double {
    return Double(minutesIntoDay()) / 1440
}

/// Used to weight a number which becomes more certain as a day progresses, with full certainty at 8pm.
func weightForCertainty(input: Int) -> Int {
    var factor: Double = (Double(minutesIntoDay()) + 1) / 1200
    if factor > 1 {  factor = 1 }
    return Int(Double(input) * factor)
}

/// Used to weight the user's "left to eat" figure based on the time into the day and the closeness to the user's set "final meal time". Weights more generously the closer to final meal time it is.
func weightCanEatNow(input: Int) -> Int {
    var factor = Double(minutesIntoDay() + 1)/Double(settingsObj.finalMealTime)
    
    if factor > 1 { factor = 1 }
    else { factor = factor * factor }
    return Int(Double(input) * factor)
}

/// Return the weighting style to use based on the user's settings.
func getWeightingStyle() -> Int {
    if settingsObj.differentWeights != true {
        return settingsObj.weightingStyle
    } else {
        switch getDayOfWeek() {
            case 1: return settingsObj.sunWeight
            case 2: return settingsObj.monWeight
            case 3: return settingsObj.tuesWeight
            case 4: return settingsObj.wedsWeight
            case 5: return settingsObj.thursWeight
            case 6: return settingsObj.friWeight
            case 7: return settingsObj.satWeight
            default: return settingsObj.weightingStyle
        }
    }
}

/// Project the user's active calories. Style and timeInput are optional, if not given then the user default's and the minutes into the day now will be used respectively.
func weightActiveProjection(input: Int, style: Int = getWeightingStyle(), timeInput: Int = minutesIntoDay(), actQuot: Double) -> Int {
    var doubleInput = Double(input)
    var usedActQuot: Double = actQuot
    let time: Double = Double(timeInput)
    
    var startTime: Double = 0
    var stopTime: Double = 1440
    var weightTime: Double
    var weightFactor: Double
    var finalWeightFactor: Double
    
    if style == -2 {
        // Don't weight down predictions at all
        usedActQuot = 1
    } else if style == -1 {
        // Forgiving
        doubleInput = 1 * doubleInput
        usedActQuot = 1
        startTime = 240
    } else if style == 0 {
        // Default
        doubleInput = 0.5 * doubleInput
        stopTime = 1320
    } else if style == 1 {
        // Harsh
        doubleInput = 0.25 * doubleInput
        stopTime = 1320
    } else if style == 2 {
        // Don't make any predictions of anything
    } else if style == 3 {
        // The old default
        doubleInput = 0.875 * doubleInput
        usedActQuot = 1
        stopTime = 1320
    }

    if time < startTime {
        weightTime = startTime
    } else {
        weightTime = time
    }
    
    switch style {
        case 2: weightFactor = 0
        default: weightFactor = weightTime/stopTime
    }
    
    switch style {
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

/// Returns true if the date received is on a day after today.
func isAfterToday(date: Date) -> Bool
{
    if date > getMidnightOnDayAfter(date: Date()) {
        return true
    } else {
        return false
    }
}

/// Returns the current time of day on the date passed. For instance, if passed 19:02 on the 29th June, but it is 16:45, it will return 16:45 on the 29th June.
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
    /// Returns the number of days between two dates.
    func numberOfDaysBetween(_ from: Date, and to: Date) -> Int {
        let fromDate = startOfDay(for: from) // <1>
        let toDate = startOfDay(for: to) // <2>
        let numberOfDays = dateComponents([.day], from: fromDate, to: toDate) // <3>
        
        return numberOfDays.day!
    }
}

/// Returns the negation of a number. Needed for extremely dumb SwiftUI related reasons.
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
        let calsPerKg: Double = 7700
        let calsToLose = weight * calsPerKg
        let result = Int(calsToLose) / deficit
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
