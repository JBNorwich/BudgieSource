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

struct Disclaimer: View {
    @Binding var displayed: Bool
    
    @Environment(\.openURL) var openURL
    
    var body: some View {
        NavigationStack {
            List {
                Section (header: Text("This app isn't medical advice")) {
                    Text("Budgie Diet is for information purposes only, its maker is not a medical professional, and its suggestions are not a substitute for professional medical advice. It's best to consult your doctor before starting any new diet plan.")
                }
                
                
                Section (header: Text("This app could be wrong")) {
                    Text("This app estimates your daily calorie budget using Apple Health data, manual calculations, and various formulae. Any of these could be inaccurate or even completely wrong.")
                }
                
                Section (header: Text("You may not lose weight")) {
                    Text("Everyone’s metabolism and lifestyle are unique. Weight changes can result from fat, muscle, or water fluctuations. Calorie counts on food may be inaccurate, and you might forget or mislog food. As such, your weight loss may not match expectations.\n\nThe \"Expected weight loss\" figures that the app provides are guidelines only.")
                }
                
                Section(header: Text("You are responsible for your choices")) {
                    Text("Budgie Diet will let you choose a target calorie deficit to aim for. It is for you, in discussion with your doctor, to work out what calorie deficit is right for you, and whether to use this app or diet at all. Its suggestions are purely advisory, and are not specific to you or your needs.\n\nThe maker of this app is not responsible for any harm caused by choosing a diet that is too restrictive for you.")
                }
                
                Section(header: Text("Struggling with food or weight?")) {
                    Text("If food, dieting or your weight feels like it's taking over your life, you're not alone and support is available from charities and medical professionals. Budgie Diet is a calorie tracker, not a treatment tool.")
                    Link("Beat Eating Disorders (UK)", destination: URL(string: "https://www.beateatingdisorders.org.uk")!)
                    Link("National Eating Disorders Association (USA)", destination: URL(string: "https://www.nationaleatingdisorders.org")!)
                    Link("NHS guidance on eating disorders", destination: URL(string: "https://www.nhs.uk/mental-health/feelings-symptoms-behaviours/behaviours/eating-disorders/overview/")!)
                }
            }
            .navigationTitle("Disclaimer")
        }
    }
}

#Preview {
    struct Preview: View {
        @State var changed: Bool = true

        var body: some View {
            Disclaimer(displayed: $changed)
        }
    }
    
    return Preview()
}
