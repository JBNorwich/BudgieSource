//
//  DataView.swift
//  Budgie
//
//  Created by Joe Baldwin on 27/08/2024.
//

import SwiftUI

struct DataView: View {
    @Binding var dataLump: TodayLump
    @Binding var dataObject: HealthData
    
    var body: some View {
//        RoundedRectangle(cornerRadius: 24)
//            .fill(.regularMaterial)
//            .overlay() {
                VStack {
                    HStack{
                        VStack {
                            VStack {
                                HStack{
                                    Image (systemName: "figure.walk")
                                    Text("ACTIVE")
                                }
                                
                                HStack {
                                    Text("NOW")
                                        .font(.caption)
                                    Spacer()
                                    Text(dataLump.activeCalories.formatted())
                                        .font(.caption)
                                        .contentTransition(.numericText())
                                }
                                if dataLump.projectedActive != 0 {
                                    HStack {
                                        Text("PROJECTED")
                                            .font(.caption)
                                        Spacer()
                                        Text(dataLump.projectedActive.formatted())
                                            .font(.caption)
                                            .contentTransition(.numericText())
                                    }
                                }
                                Divider()
                                HStack{
                                    Image (systemName: "sofa")
                                    Text("RESTING")
                                }
                                HStack {
                                    Text("NOW")
                                        .font(.caption)
                                    Spacer()
                                    Text(dataLump.basalCalories.formatted())
                                        .font(.caption)
                                        .contentTransition(.numericText())
                                }
                                if dataLump.projectedBasal != 0 {
                                    HStack {
                                        Text("PROJECTED")
                                            .font(.caption)
                                        Spacer()
                                        Text(dataLump.projectedBasal.formatted())
                                            .font(.caption)
                                            .contentTransition(.numericText())
                                    }
                                }
                                if settingsObj.desiredDeficit != 0
                                {
                                    Divider()
                                    HStack {
                                        Text("TOTAL")
                                            .font(.caption)
                                        Spacer()
                                        Text(dataLump.totalProjCalories.formatted())
                                            .font(.caption)
                                            .contentTransition(.numericText())
                                    }
                                    HStack {
                                        if settingsObj.surplusMode == false {
                                            Text("DEFICIT")
                                                .font(.caption)
                                        } else {
                                            Text("SURPLUS")
                                                .font(.caption)
                                        }
                                        Spacer()
                                        Text(negate(value: settingsObj.desiredDeficit).formatted())
                                            .font(.caption)
                                            .contentTransition(.numericText())
                                        }
                                }
                                Divider()
                                HStack {
                                    Text("BUDGET")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    Text(dataLump.totalBudget.formatted())
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .multilineTextAlignment(.leading)
                                        .contentTransition(.numericText())
                                }
                            }
                        }
                        .padding()
                        Spacer()
                        Divider()
                        Spacer ()
                        VStack {
                            VStack {
                                Spacer()
                                HStack{
                                    Image(systemName: "fork.knife.circle")
                                    Text("EATEN")
                                }
                                Text(dataLump.eatenCalories.formatted())
                                    .font(.title)
                                    .contentTransition(.numericText())
                                Spacer()
                                Divider()
                                Spacer()
                                HStack{
                                    Image (systemName: "gauge.with.needle")
                                    Text("LEFT")
                                }
                                Text(dataLump.totalBudgetRem.formatted())
                                    .font(.title)
                                    .contentTransition(.numericText())
                                Spacer()
                                if settingsObj.manualMode == true {
                                    Divider()
                                    Spacer()
                                    Label("Calories out are estimated, and won't reflect real activity", systemImage: "info.circle")
                                        .font(.caption)
                                    Spacer()
                                } else if dataLump.activeEstimated == true && dataLump.basalEstimated == true {

                                    Divider()
                                    Spacer()
                                    Label("Your calories out are being estimated, and won't reflect real activity", systemImage: "info.circle")
                                        .font(.caption)
                                    Spacer()
                                } else if dataLump.activeEstimated == true {
                                    Divider()
                                    Spacer()
                                    Label("Your active calories are being estimated, and won't reflect real activity", systemImage: "info.circle")
                                        .font(.caption)
                                    Spacer()
                                } else if dataLump.basalEstimated == true {

                                    Divider()
                                    Spacer()
                                    Label("Your resting calories are being estimated, and won't reflect real activity", systemImage: "info.circle")
                                        .font(.caption)
                                    Spacer()
                                }
                            }

                        }
                    }
                }

            }
//    }
}

#Preview {
    
    struct Preview: View {
        @State var dummyData = TodayLump()
        @State var healthData = HealthData()
        
        var body: some View {
            DataView(dataLump:$dummyData, dataObject: $healthData)
        }
    }
    
    return Preview()
}
