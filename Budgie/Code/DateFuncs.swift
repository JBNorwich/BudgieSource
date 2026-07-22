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

/// The slice of the daily budget kept aside for the final meal, as a fraction of the budget.
/// A constant rather than a setting: a sensible default for the 90%, not worth another toggle.
let mealReserveFraction = 0.35

/// Returns midnight on a day offset from another day.
private func midnight(daysOffset: Int, from date: Date) -> Date {
    let calendar = Calendar.current
    guard let adjusted = calendar.date(byAdding: .day, value: daysOffset, to: date) else {
        return calendar.startOfDay(for: date) // fallback rather than crash, in the unlikely event this fails
    }
    return calendar.startOfDay(for: adjusted)
}

/// Returns the start of the day for the date passed. Simple wrapper for calendar.startOfDay.
func getStartOfDay(date: Date) -> Date {
    let calendar = Calendar.current
    return calendar.startOfDay(for: date)
}

/// Every day's start-of-day date in `[from, to)`, one per calendar day — used to densify a
/// day-bucketed series so a day with no data still gets an explicit (zero) entry rather than being
/// omitted, which would otherwise narrow a chart's x-axis to only the days that happened to have data.
func datesInRange(from: Date, to: Date) -> [Date] {
    let calendar = Calendar.current
    var day = calendar.startOfDay(for: from)
    let end = calendar.startOfDay(for: to)
    var days: [Date] = []
    while day < end {
        days.append(day)
        guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
        day = next
    }
    return days
}

/// Returns midnight on the day before the date passed. For example, if you passed this function 19:02 on the 29th June, this would return 00:00 on the 28th June.
func getMidnightOnDayBefore(date: Date) -> Date { midnight(daysOffset: -1, from: date) }

/// Returns midnight on the day after the date passed. For example, if you passed this function 19:02 on the 29th June, it would return 00:00 on the 30th June.
func getMidnightOnDayAfter(date: Date) -> Date { midnight(daysOffset: 1, from: date) }

/// Returns midnight on the date 7 days before the one passed. For example, if you passed this function 19:02 on the 29th June, it would return 00:00 on the 22nd June.
func getWeekBeforeDate(date: Date) -> Date { midnight(daysOffset: -7, from: date) }

/// Returns the number of minutes that have passed in the current day. Will return 0 at midnight.
func minutesIntoDay() -> Int {
    let date = Date()
    let calendar = Calendar.current
    return (60 * calendar.component(.hour, from: date)) + calendar.component(.minute, from: date)
}

/// Returns a simple Double() percentage of the minutes out of the 1,440 that there are in a day.
func getPercentOfDayDone() -> Double {
    return Double(minutesIntoDay()) / 1440
}

/// The "left to eat" square-law ramp plus meal-reserve release, taking its inputs explicitly rather
/// than reading globals — shared by `weightCanEatNow()` below and the widget, which can't trust its
/// own process's `settingsObj`/clock reads to be current and previously carried a duplicate copy.
func canEatNow(budget: Int, minsIntoDay: Int, finalMealTime: Int) -> Int {
    let mealTime = max(finalMealTime, 1)
    let minsNow = minsIntoDay + 1
    guard minsNow < mealTime else { return budget }

    let factor = pow(Double(minsNow) / Double(mealTime), 2)

    // Ease the reserved meal back into the budget over the final stretch before
    // meal time, so it arrives gradually rather than all at once.
    let releaseWindow = 45.0
    let released = max(0, Double(minsNow) - (Double(mealTime) - releaseWindow)) / releaseWindow
    let reserved = Double(budget) * mealReserveFraction * (1 - released)

    return Int(min(Double(budget) * factor, Double(budget) - reserved))
}

/// Used to weight the user's "left to eat" figure based on the time into the day and the closeness to the user's set "final meal time". Weights more generously the closer to final meal time it is.
func weightCanEatNow(input: Int) -> Int {
    canEatNow(budget: input, minsIntoDay: minutesIntoDay(), finalMealTime: settingsObj.finalMealTime)
}

/// Return the weighting style to use based on the user's settings.
func getWeightingStyle() -> Int {
    if settingsObj.differentWeights != true {
        return settingsObj.weightingStyle
    } else {
        switch Calendar.current.component(.weekday, from: Date()) {
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
    return newDate ?? date
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
    return Calendar.current.date(from: dateComponents) ?? Calendar.current.startOfDay(for: Date())
}

/// Formats a future duration of time (ETA) in a fuzzy format.
func formatDuration(days: Int) -> String {
    if days < 7 {
        return days > 0 ? "about \(days) days" : "not very long from now"
    }
    let weeks = (days + 6) / 7
    if weeks < 12 {
        return "about \(weeks) weeks"
    }
    if weeks > 52 {
        return "over a year"
    }
    let months = (days + 29) / 30
    return "about \(months) months"
}

private func daysToChangeWeight(weight: Double, calsPerDay: Int, calsPerKg: Double) -> Int {
    guard weight != 0, calsPerDay != 0 else { return 0 }
    return Int(weight * calsPerKg) / calsPerDay
}

/// Calculates the days it will take to lose a given amount of weight, given the amount of weight to lose in kilos and the expected caloric deficit.
func getDaysToLose(weight: Double, deficit: Int) -> Int { daysToChangeWeight(weight: weight, calsPerDay: deficit, calsPerKg: 7700) }

/// Calculates the days it will take to gain a given amount of weight, given the amount of weight to lose in kilos and the expected caloric deficit.
func getDaysToGain(weight: Double, surplus: Int) -> Int { daysToChangeWeight(weight: weight, calsPerDay: surplus, calsPerKg: 2500) }

func roundDoubleWeight(input: Double) -> Double {
    return round(input * 10) / 10
}
