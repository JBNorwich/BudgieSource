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
    
    private struct DataViewRow: View {
        let imageName: String
        let text: String
        let number: Int
        
        var body: some View {
            HStack {
                HStack {
                    Image(systemName: imageName)
                        .frame(minWidth: 30)
                    Text(text)
                }
                Spacer()
                Text(number.formatted())
                    .contentTransition(.numericText())
            }
        }
    }
    
    private struct DataViewSumRow: View {
        let imageName: String
        let text: String
        let number: Int
        
        var body: some View {
            HStack {
                HStack {
                    Image(systemName: imageName)
                        .frame(minWidth: 30)
                        .fontWeight(.bold)
                    Text(text)
                        .fontWeight(.bold)
                }
                Spacer()
                Text(number.formatted())
                    .fontWeight(.bold)
                    .contentTransition(.numericText())
            }
        }
    }
    
    private struct DataViewHeader: View {
        let imageName: String
        let leftText: String
        let rightText: String
        
        var body: some View {
            HStack {
                HStack {
                    Image(systemName: imageName)
                        .frame(minWidth: 30)
                        .foregroundStyle(.secondary)
                    Text(leftText.uppercased())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(rightText.uppercased())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private struct DataViewDivider: View {
        var body: some View {
            HStack {
                Spacer()
                VStack {
                    Divider()
                        .frame(maxWidth: 100)
                }
            }
        }
    }
    
    private struct DataViewAlert: View {
        let imageName: String
        let text: String
        
        var body: some View {
            Label(text, systemImage: imageName)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    var body: some View {
        VStack {
            VStack {
                DataViewHeader(imageName: "figure.walk", leftText: "Active calories", rightText: "Calories")
                DataViewRow(imageName: "flame.circle", text: "Burned so far today", number: dataLump.activeCalories)
                if dataLump.projectedActive != 0 { DataViewRow(imageName: "questionmark.circle", text: "Projected future", number: dataLump.projectedActive) }
            }
            VStack {
                DataViewHeader(imageName: "sofa", leftText: "Resting calories", rightText: "Calories")
                DataViewRow(imageName: "flame.circle", text: "Burned so far today", number: dataLump.basalCalories)
                if dataLump.projectedBasal != 0 { DataViewRow(imageName: "questionmark.circle", text: "Projected future", number: dataLump.projectedBasal) }
            }
            
            DataViewDivider()
            
            if settingsObj.desiredDeficit != 0 {
                DataViewRow(imageName: "equal.circle", text: "Total burned today", number: dataLump.totalProjCalories)
                settingsObj.desiredDeficit > 0
                ? DataViewRow(imageName: "arrow.down", text: "Target deficit", number: -settingsObj.desiredDeficit)
                : DataViewRow(imageName: "arrow.up", text: "Target surplus", number: -settingsObj.desiredDeficit)
            }
            
            settingsObj.capBudget && dataLump.budgetAtCap
            ? DataViewRow(imageName: "hat.cap", text: "Budget at cap", number: dataLump.budgetOverCap)
            : nil
            
            DataViewDivider()
            
            DataViewSumRow(imageName: "equal.circle", text: "Total calorie budget", number: dataLump.totalBudget)
            
            if dataLump.eatenCalories != 0 {
                DataViewDivider()
                DataViewRow(imageName: "fork.knife", text: "Eaten today", number: -dataLump.eatenCalories)
                if dataLump.totalBudgetRem != 0 {
                    dataLump.totalBudgetRem > 0
                    ? DataViewRow(imageName: "face.smiling", text: "Left in budget today", number: dataLump.totalBudgetRem)
                    : DataViewRow(imageName: "gauge.with.dots.needle.bottom.100percent", text: "Over total budget by", number: -dataLump.totalBudgetRem)
                }
            }
            if dataLump.activeEstimated == true || dataLump.budgetAtCap == true || dataLump.budgetAtMin == true {
                Divider()
                dataLump.activeEstimated
                ? DataViewAlert(imageName: "info.circle",text: "Your active calorie burn figures are estimated, so your budget doesn't reflect your real activity today.")
                : nil
                dataLump.budgetAtCap
                ? DataViewAlert(imageName: "info.circle", text: "Your budget for today has been capped at the amount chosen in Settings.")
                : nil
                dataLump.budgetAtMin
                ? DataViewAlert(imageName: "exclamationmark.octagon", text: "Your budget was calculated as lower than the minimum of 1,200 calories, so it has been set at that amount.")
                : nil
            }
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
