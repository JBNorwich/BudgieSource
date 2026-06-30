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

struct BudgetHelperView: View {
    @Binding var isPresented: Bool
    @Binding var doubleDeficit: Double
    
    var hideZero: Bool = false
    
    @State var displaying1000kcalWarning: Bool = false
    
    var body: some View {

        Form {
            if settingsObj.isFirstRun == false {
                Text(.init(healthDisclaimer))
                    .multilineTextAlignment(.center)
                    .padding()
            }
            if hideZero != true {
                Section(footer: Text("Choose this if your goal is to maintain your current weight.")) {
                    Button("No deficit at all")
                    {
                        //HealthData.updateDesiredDeficit(newDeficit: 0)
                        settingsObj.desiredDeficit = 0
                        doubleDeficit = 0
                        isPresented = false
                    } .fontWeight(.bold)
                }
            }
            Section(footer: Text("Most people will find this easy to stick to.")) {
                Button("Easy - 250kcal per day")
                {
                    //HealthData.updateDesiredDeficit(newDeficit: 250)
                    settingsObj.desiredDeficit = 250
                    doubleDeficit = 250
                    isPresented = false
                } .fontWeight(/*@START_MENU_TOKEN@*/.bold/*@END_MENU_TOKEN@*/)
                HStack{
                    Text("**Expected weight loss**")
                    Spacer()
                    if settingsObj.impMetric == 0 {
                        Text("225g a week")
                    } else {
                        Text("½lb a week")
                    }
                    
                }
                HStack{
                    Text("**Same calories as**")
                    Spacer()
                    if settingsObj.whalesEverywhere != true
                    {
                        Text("Chocolate bar")
                    } else {
                        Text("0.000000833333333 whales")
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            Section(footer: Text("This is a good recommended starting point for people with a bit of weight to lose - not too hard, not too easy.")) {
                Button("Moderate - 500kcal per day")
                {
                    //HealthData.updateDesiredDeficit(newDeficit: 500)
                    settingsObj.desiredDeficit = 500
                    doubleDeficit = 500
                    isPresented = false
                } .fontWeight(/*@START_MENU_TOKEN@*/.bold/*@END_MENU_TOKEN@*/)
                HStack{
                    Text("**Expected weight loss**")
                    Spacer()
                    if settingsObj.impMetric == 0 {
                        Text("450g a week")
                    } else {
                        Text("1lb a week")
                    }
                }
                HStack{
                    Text("**Same calories as**")
                    Spacer()
                    if settingsObj.whalesEverywhere != true
                    {
                        Text("Two cupcakes")
                    } else {
                        Text("0.000001666666667 whales")
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            Section(footer: Text("This level of deficit may work for you if you exercise a lot, or you are very overweight. Otherwise, you may not be able to eat enough on the budget that this will give you.")) {
                Button("Hard - 750kcal per day")
                {
                    //HealthData.updateDesiredDeficit(newDeficit: 500)
                    settingsObj.desiredDeficit = 750
                    doubleDeficit = 750
                    isPresented = false
                } .fontWeight(/*@START_MENU_TOKEN@*/.bold/*@END_MENU_TOKEN@*/)
                HStack{
                    
                    Text("**Expected weight loss**")
                    Spacer()
                    if settingsObj.impMetric == 0 {
                        Text("700g a week")
                    } else {
                        Text("1½lb a week")
                    }
                    
                }
                HStack{
                    Text("**Same calories as**")
                    Spacer()
                    if settingsObj.whalesEverywhere != true
                    {
                        Text("Half a roast chicken")
                    } else {
                        Text("0.0000025 whales")
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            if settingsObj.whalesEverywhere != true {
                Section(footer: Text("You should only choose this if you have a lot of weight to lose (i.e. a body mass index of more than 40). Virtually everyone else will struggle to eat enough to get enough energy and vital nutrients.")) {
                    Button("Very hard - 1,000kcal per day")
                    {
                        displaying1000kcalWarning = true
                    } .fontWeight(/*@START_MENU_TOKEN@*/.bold/*@END_MENU_TOKEN@*/)
                        .foregroundStyle(.red)
                }
            } else {
                Section(footer: Text("Simple question - are you a whale? If not, don't pick this. If you are, how are you using an iPhone?")) {
                    Button("🐳 Very hard - 1,000kcal per day")
                    {
                        displaying1000kcalWarning = true
                    } .fontWeight(/*@START_MENU_TOKEN@*/.bold/*@END_MENU_TOKEN@*/)
                        .foregroundStyle(.red)
                }
            }
        }
        
        .sheet(isPresented: $displaying1000kcalWarning)
        {
            VStack {
                Text("Seriously...")
                    .font(.largeTitle)
                    .multilineTextAlignment(.center)
                Text("A 1,000kcal daily deficit poses **serious health risks** unless you have significant weight to lose. Most people can’t sustain this while getting enough nutrients.")
                    .multilineTextAlignment(.center)
                    .padding()
                Text("Budgie Diet is hard coded to not give you a budget below 1,200kcal under any circumstances, so for a great number of people, this will have no effect anyway.")
                    .multilineTextAlignment(.center)
                    .padding()
                Text("It is strongly recommended that you do not pursue this without medical supervision. The app maker is not responsible for any health issues caused by choosing too high a deficit.")
                    .multilineTextAlignment(.center)
                    .padding()
                Button("Choose a different deficit") {
                    displaying1000kcalWarning = false
                }
                .font(.title)
                .padding()
                Button("Set deficit to 1,000") {
                    settingsObj.desiredDeficit = 1000
                    doubleDeficit = 1000
                    displaying1000kcalWarning = false
                    isPresented = false
                }
                .foregroundStyle(.red)

            }.padding()
        }
            .presentationDragIndicator(.visible)
    }
}

#Preview {
    struct Preview: View {
        @State var isPresented = Bool()
        @State var doubleDeficit = Double()
        var body: some View {
            BudgetHelperView(isPresented: $isPresented, doubleDeficit: $doubleDeficit)
        }
    }

    return Preview()
}
