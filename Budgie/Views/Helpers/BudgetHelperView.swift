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

/// One of the "Easy/Moderate/Hard" deficit choices — same shape (button + expected loss + whale-facts
/// comparison), differing only in these values. The "No deficit"/"Very hard" choices have genuinely
/// different shapes (no loss/comparison rows, or a confirmation gate) and stay bespoke below.
private struct DeficitOption {
    let label: String
    let kcal: Int
    let footer: String
    let metricLoss: String
    let imperialLoss: String
    let comparison: String
    let whaleFactor: String
}

struct BudgetHelperView: View {
    @Binding var isPresented: Bool
    var hideZero: Bool = false
    @State var displaying1000kcalWarning: Bool = false

    private static let deficitOptions: [DeficitOption] = [
        DeficitOption(label: "Easy", kcal: 250,
                      footer: "Most people will find this easy to stick to.",
                      metricLoss: "225g a week", imperialLoss: "½lb a week",
                      comparison: "Chocolate bar", whaleFactor: "0.000000833333333 whales"),
        DeficitOption(label: "Moderate", kcal: 500,
                      footer: "This is a good recommended starting point for people with a bit of weight to lose - not too hard, not too easy.",
                      metricLoss: "450g a week", imperialLoss: "1lb a week",
                      comparison: "Two cupcakes", whaleFactor: "0.000001666666667 whales"),
        DeficitOption(label: "Hard", kcal: 750,
                      footer: "This level of deficit may work for you if you exercise a lot, or you are very overweight. Otherwise, you may not be able to eat enough on the budget that this will give you.",
                      metricLoss: "700g a week", imperialLoss: "1½lb a week",
                      comparison: "Half a roast chicken", whaleFactor: "0.0000025 whales"),
    ]

    @ViewBuilder
    private func deficitSection(_ option: DeficitOption) -> some View {
        Section(footer: Text(option.footer)) {
            Button("\(option.label) - \(option.kcal)kcal per day") {
                settingsObj.desiredDeficit = option.kcal
                isPresented = false
            }.fontWeight(.bold)
            HStack {
                Text("**Expected weight loss**")
                Spacer()
                Text(settingsObj.impMetric == 0 ? option.metricLoss : option.imperialLoss)
            }
            HStack {
                Text("**Same calories as**")
                Spacer()
                if settingsObj.whalesEverywhere != true {
                    Text(option.comparison)
                } else {
                    Text(option.whaleFactor)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }

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
                        settingsObj.desiredDeficit = 0
                        isPresented = false
                    } .fontWeight(.bold)
                }
            }
            ForEach(Self.deficitOptions, id: \.label) { option in
                deficitSection(option)
            }
            if settingsObj.whalesEverywhere != true {
                Section(footer: Text("This level of deficit is really only appropriate for people with a significant amount of weight to lose, and even then might make it hard to get enough energy and nutrients. If you're not sure if this applies to you, discuss this with your doctor before choosing this option.")) {
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
        
        .sheet(isPresented: $displaying1000kcalWarning) {
            ThousandKcalWarningSheet(
                isDisplayed: $displaying1000kcalWarning,
                onConfirm: {
                    settingsObj.desiredDeficit = 1000
                    isPresented = false
                }
            )
        }
        .presentationDragIndicator(.visible)
    }
}

struct ThousandKcalWarningSheet: View {
    @Binding var isDisplayed: Bool
    /// Called when the user confirms they want the 1,000 kcal deficit.
    var onConfirm: () -> Void
    /// Called when the user backs out; the caller should restore the prior deficit.
    var onCancel: () -> Void = {}

    @State private var secondsRemaining = 5

    var body: some View {
        VStack {
            Text("Seriously...")
                .font(.largeTitle)
                .multilineTextAlignment(.center)
            Text("A 1,000kcal daily deficit poses **serious health risks** unless you have significant weight to lose. Most people can't sustain this while getting enough nutrients.")
                .multilineTextAlignment(.center)
                .padding()
            Text("Budgie Diet is hard coded to not give you a budget below 1,200kcal under any circumstances, so for a great number of people, this will have no effect anyway.")
                .multilineTextAlignment(.center)
                .padding()
            Text("It is strongly recommended that you do not pursue this without medical supervision.")
                .multilineTextAlignment(.center)
                .padding()
            Button("Choose a different deficit") {
                onCancel()
                isDisplayed = false
            }
            .font(.title)
            .padding()
            Button(secondsRemaining > 0 ? "Set deficit to 1,000 (\(secondsRemaining))" : "Set deficit to 1,000") {
                onConfirm()
                isDisplayed = false
            }
            .foregroundStyle(secondsRemaining > 0 ? Color.gray : Color.red)
            .disabled(secondsRemaining > 0)
        }
        .padding()
        .task {
            for _ in 0..<5 {
                try? await Task.sleep(for: .seconds(1))
                secondsRemaining -= 1
            }
        }
    }
}

#Preview {
    struct Preview: View {
        @State var isPresented = Bool()
        var body: some View {
            BudgetHelperView(isPresented: $isPresented)
        }
    }

    return Preview()
}
