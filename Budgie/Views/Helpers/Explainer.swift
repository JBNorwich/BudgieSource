//
//  Explainer.swift
//  Budgie Diet
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
                    Text("Budgie Diet estimates your daily calorie burn from last week’s averages, subtracts your desired deficit, and calculates a **daily eating budget**. You can see this budget and how it's worked out for you on the Today screen.\n\nBudgie Diet also works out a **target** for you, which is how much it thinks you should have eaten at a given point in the day.\n\nYour budget and target adjust throughout the day based on your activity; up if you exercise a lot, or down if you exercise less than usual.")
                        .padding()
                        .multilineTextAlignment(.leading)
                    
                    VStack {
                        MeterView(todayLump: $dummyLump, dummy: true)
                    }.frame(maxWidth: 200)
                        .padding()
                    
                    Text("The figure in the circle shows you how you're doing **against your target** - how much Budgie Diet thinks you can eat now without going over your budget later.\n\nThe bar around the outside shows you **how much of your total daily budget you've eaten**. If it's green, you've eaten less of your budget than you'd expect for this time of day; if it's red, you've eaten more.\n\nYou can also see the exact amount you have left overall in the \"Today in detail\" box on the Today screen.\n\nIn short - if you follow the \"Can eat now\" figure, you will stay within your budget and meet your calorie goal!").padding()
                    
                    Button("Close") {
                        showing = false
                    }
                        .buttonStyle(.borderedProminent)
                }
                .navigationTitle("How Budgie Diet works")
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
