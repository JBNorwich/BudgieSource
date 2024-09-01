//
//  DataView.swift
//  Budgie
//
//  Created by Joe Baldwin on 27/08/2024.
//

import SwiftUI

struct NewDataView: View {
    @Binding var dataLump: TodayLump
    
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
        Spacer()
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

        if dataLump.desiredDeficit != 0 {
            HStack {
                Image(systemName: "equal.circle")
                    .frame(minWidth: 30)
                Text("Total burned today")
                Spacer()
                Text(dataLump.totalProjCalories.formatted())
                    .contentTransition(.numericText())
            }
            HStack {
                if dataLump.desiredDeficit > 0 {
                    Image(systemName: "arrow.down")
                        .frame(minWidth: 30)
                    Text("Target deficit")
                    Spacer()
                    Text("-"+dataLump.desiredDeficit.formatted())
                } else {
                        Image(systemName: "arrow.up")
                            .frame(minWidth: 30)
                        Text("Target surplus")
                        Spacer()
                        Text(negate(number: dataLump.desiredDeficit).formatted())
                }
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
        if dataLump.activeEstimated == true || dataLump.basalEstimated == true {
            Divider()
            Label("Your calorie burn figures are estimated, and don't reflect your real activity today.", systemImage: "info.circle")
        }
    }
}

#Preview {
    
    struct Preview: View {
        @State var dummyData = TodayLump()
        
        var body: some View {
            NewDataView(dataLump:$dummyData)
        }
    }
    
    return Preview()
}
