//
//  Disclaimer.swift
//  Budgie
//
//  Created by Joe Baldwin on 25/08/2024.
//

import SwiftUI
import StoreKit

struct Donate: View {
    var body: some View {
                VStack {
                    Image("Thumbsup")
                        .resizable()
                        .frame(maxWidth: 100,maxHeight: 100)
                    VStack {
                        Text("Thank you for using Budgie! This app is and always will be free of charge for everyone, with no ads, no tracking, no logins, no faff.\n\nIf you like Budgie, please do send me a protein bar (or rather, the price of one) using the button below!")
                            .padding()
                            
                            ProductView(id: "proteinBar") {
                                Image("Bar Emoji")
                                    .resizable()
                                    .scaledToFit()
                            }
                        }
                }.padding()
                Spacer()
        .navigationTitle("Buy me a protein bar")
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
