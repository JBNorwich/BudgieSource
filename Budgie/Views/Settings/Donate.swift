//
//  Disclaimer.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 25/08/2024.
//

import SwiftUI
import StoreKit

struct Donate: View {
    var body: some View {
        var donated: Bool = false
        
            VStack {
                Image("Thumbsup")
                    .resizable()
                    .frame(maxWidth: 90,maxHeight: 100)
                VStack {
                    Text("Thank you for using Budgie Diet! This app is and always will be free of charge for everyone, with no ads, no tracking, no logins, no hassle.\n\nIf you like the app, please do help me in _my_ fitness goals by donating me a protein bar (or rather, the price of one) using the button below!")
                        .padding()
                    
                    ProductView(id: "ProteinBar") {
                        Image("Bar Emoji")
                            .resizable()
                            .scaledToFit()
                    }.onInAppPurchaseCompletion {_,_ in
                        settingsObj.donated = true
                        donated = true
                    }
                    
                    GroupBox {
                        VStack {
                            Image("HeartEyes")
                                .resizable()
                                .frame(maxWidth: 75,maxHeight: 100)
                            
                            Text("Thank you so much, your support really means a lot to me!\n\nPlease do feel free to drop me a line on budgieapp@icloud.com if you'd like to share any thoughts or suggestions.")
                        }
                    }.opacity(donated ? 1 : 0)
                }
            }.padding()
        .navigationTitle("Buy me a protein bar")
        
        .onAppear() {
            donated = settingsObj.donated
        }
    }
}

#Preview {
    struct Preview: View {
        @State var changed: Bool = true

        var body: some View {
            Donate()
        }
    }
    
    return Preview()
}
