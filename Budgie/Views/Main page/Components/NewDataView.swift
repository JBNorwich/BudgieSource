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

struct NewDataView: View {
    @EnvironmentObject var dataLump: TodayLump
    
    var body: some View {
        Spacer()
        VStack {
            HStack {
                Image(systemName: "figure.walk")
                    .frame(minWidth: 30)
                    .foregroundStyle(.secondary)
                Text("Active calories".uppercased())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Calories".uppercased())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack {
                HStack {
                    Image(systemName: "flame.circle")
                        .frame(minWidth: 30)
                    Text("Burned so far today")
                }
                Spacer()
                Text(dataLump.activeCalories.formatted())
                    .contentTransition(.numericText())
            }
            if dataLump.projectedActive != 0 {
                HStack {
                    Image(systemName: "questionmark.circle")
                        .frame(minWidth: 30)
                    Text("Projected future")
                    Spacer()
                    Text(dataLump.projectedActive.formatted())
                        .contentTransition(.numericText())
                }
            }
        }
        VStack {
            HStack {
                Image(systemName: "sofa")
                    .frame(minWidth: 30)
                    .foregroundStyle(.secondary)
                Text("Resting calories".uppercased())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Calories".uppercased())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Image(systemName: "flame.circle")
                    .frame(minWidth: 30)
                Text("Burned so far today")
                Spacer()
                Text(dataLump.basalCalories.formatted())
                    .contentTransition(.numericText())
            }
            HStack {
                Image(systemName: "questionmark.circle")
                    .frame(minWidth: 30)
                Text("Projected future")
                Spacer()
                Text(dataLump.projectedBasal.formatted())
                    .contentTransition(.numericText())
            }
        }
        HStack {
            Spacer()
            VStack {
                Divider()
                    .frame(maxWidth: 100)
            }
        }

        if settingsObj.desiredDeficit != 0 {
            HStack {
                Image(systemName: "equal.circle")
                    .frame(minWidth: 30)
                Text("Total burned today")
                Spacer()
                Text(dataLump.totalProjCalories.formatted())
                    .contentTransition(.numericText())
            }
            HStack {
                if settingsObj.desiredDeficit > 0 {
                    Image(systemName: "arrow.down")
                        .frame(minWidth: 30)
                    Text("Target deficit")
                    Spacer()
                    Text("-"+settingsObj.desiredDeficit.formatted())
                } else {
                        Image(systemName: "arrow.up")
                            .frame(minWidth: 30)
                        Text("Target surplus")
                        Spacer()
                        Text(negate(number: settingsObj.desiredDeficit).formatted())
                }
            }
        }
        
        if settingsObj.capBudget == true && dataLump.budgetAtCap == true {
            HStack {
                Image(systemName: "hat.cap")
                    .frame(minWidth: 30)
                Text("Budget at cap")
                Spacer()
                Text(dataLump.budgetOverCap.formatted())
                    .contentTransition(.numericText())
            }
        }
        
        HStack {
            Spacer()
            VStack {
                Divider()
                    .frame(maxWidth: 100)
            }
        }

        HStack {
            Image(systemName: "equal.circle")
                .frame(minWidth: 30)
                .fontWeight(.bold)
            Text("Total calorie budget")
                .fontWeight(.bold)
            Spacer()
            Text(dataLump.totalBudget.formatted())
                .fontWeight(.bold)
                .contentTransition(.numericText())
        }
        if dataLump.eatenCalories != 0 {
            HStack {
                Spacer()
                VStack {
                    Divider()
                        .frame(maxWidth: 100)
                }
            }
            HStack {
                Image(systemName: "fork.knife")
                    .frame(minWidth: 30)
                Text("Eaten today")
                Spacer()
                Text("-" + dataLump.eatenCalories.formatted())
                    .contentTransition(.numericText())
            }
            if dataLump.totalBudgetRem != 0 {
                HStack {
                    if dataLump.totalBudgetRem > 0 {
                        Image(systemName: "face.smiling")
                            .frame(minWidth: 30)
                        Text("Left in budget today")
                        Spacer()
                        Text(dataLump.totalBudgetRem.formatted())
                            .contentTransition(.numericText())
                    } else if dataLump.totalBudgetRem < 0 {
                        Image(systemName: "gauge.with.dots.needle.bottom.100percent")
                            .frame(minWidth: 30)
                        Text("Over total budget by")
                        Spacer()
                        Text(negate(number: dataLump.totalBudgetRem).formatted())
                            .contentTransition(.numericText())
                    }
                }
            }
        }
        if dataLump.activeEstimated == true || dataLump.budgetAtCap == true || dataLump.budgetAtMin == true {
            Divider()
        }
        if dataLump.activeEstimated == true {
            Label("Your active calorie burn figures are estimated, so your budget doesn't reflect your real activity today.", systemImage: "info.circle")
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        if dataLump.budgetAtCap == true {
            Label("Your budget for today has been capped at the amount chosen in Settings.", systemImage: "info.circle")
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        if dataLump.budgetAtMin == true {
            Label("Your budget was calculated as lower than the minimum of 1,200 calories, so it has been set at that amount.", systemImage: "exclamationmark.octagon")
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    
    struct Preview: View {
        @State var dummyData = TodayLump()
        
        var body: some View {
            NewDataView().environmentObject(dummyData)
        }
    }
    
    return Preview()
}
