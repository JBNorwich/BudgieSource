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

struct Explainer: View {
    @Binding var showing: Bool
    @State var dummyLump: TodayLump = TodayLump()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    Text("Budgie Diet estimates your daily calorie burn from last week’s averages, subtracts your desired deficit, and calculates a **daily eating budget**. You can see this budget and how it's worked out for you on the Today screen.\n\nBudgie Diet also works out a **target** for you, which is how much it thinks you should have eaten at a given point in the day.\n\nYour budget and target adjust throughout the day based on your activity; up if you exercise a lot, or down if you exercise less than usual.")
                        .padding()
                        .multilineTextAlignment(.leading)
                    
                    VStack {
                        MeterView(dummy: true).environmentObject(dummyLump)
                    }.frame(maxWidth: 200)
                        .padding()
                    
                    Text("The figure in the circle shows you how you're doing **against your target** - how much Budgie Diet thinks you can eat now without going over your budget later.\n\nThe bar around the outside shows you **how much of your total daily budget you've eaten**. If it's green, you've eaten less of your budget than you'd expect for this time of day; if it's red, you've eaten more.\n\nYou can also see the exact amount you have left in your budget overall in the \"Your target\" box on the Today screen.\n\nIn short - if you follow the \"Can eat now\" figure, you will stay within your budget and meet your calorie goal!").padding()
                    
                    Button("Close") {
                        showing = false
                    }
                        .buttonStyle(.borderedProminent)
                }
                .navigationTitle("How this works")
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
