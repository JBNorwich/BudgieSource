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
                        Text("Budgie estimates your daily calorie burn from last week’s averages, subtracts your desired deficit, and provides your daily eating budget. You can see this budget on the Today screen.")
                            .padding()
                    } else {
                        Text("Budgie estimates your daily calorie burn from last week’s averages, adds your desired surplus, and provides your daily eating budget. You can see this budget on the Today screen.")
                            .padding()
                    }
                    
                    Text("Your budget adjusts throughout the day based on your activity; it will go up if you exercise a lot, or down if you exercise less than usual. It weights down your predicted exercise over time, to make sure that you're not told you can eat calories you won't burn off later.")
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
