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
import HealthKitUI

struct ActivityRingView: UIViewRepresentable {
    var activitySummary: HKActivitySummary

    func makeUIView(context: Context) -> HKActivityRingView {
        let frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        let view = HKActivityRingView(frame: frame)
            
        return view
    }

    func updateUIView(_ uiView: HKActivityRingView, context: Context) {
        uiView.activitySummary = self.activitySummary
    }
}

struct FitnessView: View {
    @EnvironmentObject var todayLump: TodayLump
    
    let moveColour = Color(red: 0.98039, green: 0.0666, blue: 0.3098)
    let exerciseColour = Color(red: 0.651, green: 1, blue: 0)
    let standColour = Color(red: 0, green: 1, blue: 0.9647)
    
    private struct FitnessStat: View {
        let title: String
        let value: Double
        let goal: Double
        let unit: String
        let colour: Color
        
        var body: some View {
            HStack {
                Text(title)
                    .font(.caption)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            HStack {
                Text("\(Int(value.rounded()).formatted())/\(Int(goal).formatted())")
                    .foregroundColor(colour)
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(unit.uppercased())
                    .font(.caption)
                    .foregroundColor(colour)
                Spacer()
            }
        }
    }
    
    var body: some View {
        HStack {
            VStack {
                ActivityRingView(activitySummary: todayLump.activitySummary)
                    .frame(width: 40, height: 40)
                Spacer()
            }
            Divider()
            VStack {
                FitnessStat(
                    title: "Move",
                    value: todayLump.activitySummary.activeEnergyBurned.doubleValue(for: .kilocalorie()),
                    goal: todayLump.activitySummary.activeEnergyBurnedGoal.is(compatibleWith: .kilocalorie())
                        ? todayLump.activitySummary.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie())
                        : 0,
                    unit: "kcal",
                    colour: moveColour
                )
                if let exerciseGoal = todayLump.activitySummary.exerciseTimeGoal {
                    FitnessStat(title: "Exercise", value: todayLump.activitySummary.appleExerciseTime.doubleValue(for: .minute()), goal: exerciseGoal.doubleValue(for: .minute()), unit: "min", colour: exerciseColour)
                }
                if let standGoal = todayLump.activitySummary.standHoursGoal {
                    FitnessStat(title: "Stand", value: todayLump.activitySummary.appleStandHours.doubleValue(for: .count()), goal: standGoal.doubleValue(for: .count()), unit: "hrs", colour: standColour)
                }
                Spacer()
            }
        }
    }
}
