//
//  Disclaimer.swift
//  Budgie
//
//  Created by Joe Baldwin on 25/08/2024.
//

import SwiftUI

struct Disclaimer: View {
    @Binding var displayed: Bool
    
    var body: some View {
        NavigationStack {
            List {
                Section (header: Text("This app isn't medical advice")) {
                Text("Budgie is for information purposes only, and its suggestions are not a substitute for professional medical advice. It's best to consult your doctor before starting any new diet plan.")
                }
                
                
                Section (header: Text("This app could be wrong")) {
                    Text("This app estimates your daily energy allowance using Apple Watch data, manual calculations, and various formulas. Any of these could be inaccurate or even completely wrong.")
                }
                
                Section (header: Text("You may not lose weight")) {
                    Text("Everyone’s metabolism and lifestyle are unique. Weight changes can result from fat, muscle, or water fluctuations. Calorie counts on food may be inaccurate, and you might forget or mislog food. As such, your weight loss may not match expectations.\n\nThe \"Expected weight loss\" figures that the app provides are guidelines only.")
                }
                
                Section(header: Text("You are responsible for your choices")) {
                    Text("Budgie will let you choose a target calorie deficit to aim for. It is for you, in discussion with your doctor, to work out what calorie deficit is right for you, and whether to use Budgie at all. Its suggestions are purely advisory, and are not specific to you or your needs.\n\nThe maker of this app is not responsible for any harm caused by choosing a diet that is too restrictive for you.")
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
