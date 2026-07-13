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

struct LicencesScreen: View {
    @Environment(\.openURL) var openURL
    
    var body: some View {
        NavigationStack {
            List {
                Section (header: Text("Software")) {
                    Text("Budgie Diet is free software, released under the Expat (MIT) licence. You can read it, amend it and incorporate any part of it into your own software.\n\nThe Expat licence **does not** apply to the Budgie Diet branding, which is discussed below.")
                    Link("Source code on GitHub", destination: URL(string: "https://github.com/JBNorwich/BudgieSource")!)
                    Link("Read the Expat licence", destination: URL(string: "https://www.debian.org/legal/licenses/mit")!)
                }
                
                Section (header: Text("Generic food data")) {
                    Text("The calorie and macro data for generic food items is adapted from the UK CoFID (McCance & Widdowson's \"Composition of Foods Integrated Dataset\"). © Crown copyright, contains public sector information licensed under the Open Government Licence v3.0.")
                    Link("UK CoFID", destination: URL(string: "https://www.gov.uk/government/publications/composition-of-foods-integrated-dataset-cofid")!)
                    Link("OGL v3.0", destination: URL(string: "https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/")!)
                }
                
                Section(header: Text("Food search")) {
                    Text("Food search results come from OpenFoodFacts, made available under the Open Database Licence (ODbL). Individual products are © their respective contributors.")
                    Link("OpenFoodFacts", destination: URL(string: "https://world.openfoodfacts.org")!)
                    Link("Open Database Licence", destination: URL(string: "https://opendatacommons.org/licenses/odbl/1-0/")!)
                }
                
                Section (header: Text("Branding")) {
                    Text("The name \"Budgie Diet\" and the green bird logo, and all intellectual property, trade mark rights and copyrights associated with them, are the property of Joseph Baldwin. They may not be used for, in or in connection with any other application without permission, nor may you use them for a commercial purpose (including for a fork or separate distribution of Budgie Diet, whether you charge money for it or not). However, you may redistribute unamended copies of the branding alongside the software's source code.")
                }
                
                Section (header: Text("Apple trade marks")) {
                    Text("Apple Health, Apple Watch and Apple are all trademarks of Apple Inc., and are used in a purely descriptive sense. Apple Inc. does not endorse or have any connection with this software.")
                }
            }
            .navigationTitle("Licences")
        }
    }
}

#Preview {
    struct Preview: View {
        @State var changed: Bool = true

        var body: some View {
            LicencesScreen()
        }
    }
    
    return Preview()
}
