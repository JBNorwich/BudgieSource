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

struct GaugeExplainer: View {
    @Binding var showing: Bool

    var body: some View {
        ExplainerSheet(showing: $showing, title: "Your target") {
            Text("Your **target** is how much Budgie Diet estimates you could have eaten so far today, based on your daily budget, the time of day and the final meal time set in Settings. Your **budget** is how much Budgie Diet estimates you can eat overall today while fitting within your calorie goals.")
                .padding()
                .multilineTextAlignment(.leading)

            Text("The gauge itself, and the percentage it shows, is how far over or under your target you are. A negative number, and the gauge being left of the centre, means you've eaten less than your target; a positive number, and the gauge being right of the centre, means you've eaten more than your target. If the gauge is roughly around the middle, you're about on target for the day.").padding()

            Text("The **\"Can eat now\" figure** in the circle at the top of Today is the practical version of all this: roughly how much you can eat right now while staying on target and leaving room for the rest of the day.").padding()

            Text("In practice, going slightly over or being slightly under your target won't hurt anything, and usually just means you're eating earlier or later than usual. You can use the gauge and the \"Can eat now\" figure to help you plan your food intake throughout the day.").padding()
        }
    }
}

#Preview {
    struct Preview: View {
        @State var changed: Bool = true

        var body: some View {
            GaugeExplainer(showing: $changed)
        }
    }
    
    return Preview()
}
