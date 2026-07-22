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
import StoreKit

struct Donate: View {
    @State private var donated = false
    
    var body: some View {
            VStack {
                Image("Thumbsup")
                    .resizable()
                    .frame(maxWidth: 90,maxHeight: 100)
                VStack {
                    Text("Thank you for using Budgie Diet! This app is and always will be free of charge for everyone, with no ads, no tracking, no logins, no hassle.\n\nIf you like the app, please do help me in _my_ fitness goals by donating me a protein bar (or rather, the price of one) using the button below!")
                        .padding()
                    
                    ProductView(id: "Donation") {
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
    Donate()
}
