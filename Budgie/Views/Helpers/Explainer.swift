//
//  Explainer.swift
//  Budgie
//
//  Created by Joe Baldwin on 24/08/2024.
//

import SwiftUI

struct Explainer: View {
    @Binding var showing: Bool
    @State var averageActive: Int = Int()
    @State var averageBasal: Int = Int()
    @State var totalBurned: Int = Int()
    @State var totalBudget: Int = Int()
    @State var dummyLump: TodayLump = TodayLump()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    if settingsObj.surplusMode != true
                    {
                        Text("As a starting point, Budgie predicts the calories you will burn each day based on an average of your previous week's activity. It then subtracts your desired deficit to give you an overall daily budget to eat. You can see your current budget and how it's calculated on the Today screen.")
                            .padding()
                    } else {
                        Text("Budgie predicts the calories you will burn each day based on an average of your previous week's activities. It then adds your desired surplus to give you an overall daily budget to eat.")
                            .padding()
                    }
//                    
//                    VStack {
//                        HStack {
//                            Text("AVERAGE ACTIVE CALORIES")
//                                .font(.caption)
//                            Spacer()
//                            Text(averageActive.formatted())
//                                .font(.caption)
//                        }
//                        HStack {
//                            Text("AVERAGE RESTING CALORIES")
//                                .font(.caption)
//                            Spacer()
//                            Text(averageBasal.formatted())
//                                .font(.caption)
//                        }
//                        Divider()
//                        HStack {
//                            Text("TOTAL BURNED DAILY")
//                                .font(.caption)
//                                .fontWeight(/*@START_MENU_TOKEN@*/.bold/*@END_MENU_TOKEN@*/)
//                            Spacer()
//                            Text(totalBurned.formatted())
//                                .font(.caption)
//                                .fontWeight(.bold)
//                        }
//                        if settingsObj.surplusMode != true
//                        {
//                            HStack {
//                                Text("LESS DESIRED DEFICIT")
//                                    .font(.caption)
//                                Spacer()
//                                Text("-" + settingsObj.desiredDeficit.formatted())
//                                    .font(.caption)
//                            }
//                        } else {
//                            HStack {
//                                Text("ADD DESIRED SURPLUS")
//                                    .font(.caption)
//                                Spacer()
//                                Text(negate(number:settingsObj.desiredDeficit).formatted())
//                                    .font(.caption)
//                            }
//                        }
//                        Divider()
//                        HStack {
//                            Text("TOTAL BUDGET")
//                                .font(.caption)
//                                .fontWeight(/*@START_MENU_TOKEN@*/.bold/*@END_MENU_TOKEN@*/)
//                            Spacer()
//                            Text(totalBudget.formatted())
//                                .font(.caption)
//                                .fontWeight(.bold)
//                        }
//                    }
//                    .frame(maxWidth: 250)
                    
                    Text("Budgie will adjust your budget throughout the day based on your actual activity; it will go up if you do a lot of exercise, or down if you exercise less than normal. It weights down your predicted exercise over time, to make sure that you're not told you can eat calories you won't burn off later.")
                        .padding()
                    
                    VStack {
                        MeterView(todayLump: $dummyLump, dummy: true)
                    }.frame(maxWidth: 200)
                        .padding()
                    
                    Text("The meter shows you **how many calories Budgie thinks you have left to eat right now**, based on the time of day and your activity so far.\n\nThe bar around the outside shows you **how much of your total daily budget you've eaten**. If it's green, you've eaten less of your budget than you'd expect for this time of day; if it's red, you've eaten more.\n\nYou can also see the exact amount you have left overall in the \"Today in detail\" box on the Today screen.\n\nIn short - if you follow the Left to eat figure, and stay within your budget, you will meet your calorie goal!").padding()
                    
                    Button("Close") {
                        showing = false
                    }
                        .buttonStyle(.borderedProminent)
                }
                .navigationTitle("How Budgie works")
            }
        }
    }
}

#Preview {
    struct Preview: View {
        @State var changed: Bool = true

        var body: some View {
            Explainer(showing: $changed)
        }
    }
    
    return Preview()
}
