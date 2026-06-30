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

let whaleFactsArray: [String] =
    ["Whales are good.",
    "Robbie Williams has never been a whale and neither has Olivia Rodrigo.",
    "The recommended daily allowance of whales in an average person's diet is zero.\n\n_(Seriously, this isn't a joke, please don't buy whale meat.)_",
    "Nobody has ever seen a whale that did not ordinarily live in the sea.",
    "_Clifford The Big Red Dog_ was originally envisaged as a whale, but this proved difficult to adapt into a cartoon about a domestic pet.",
    "The movie _Oppenheimer_ contains no whales whatsoever. (Several whale-centric scenes were filmed but scrapped in the final edit.)",
    "It's a well known fact that birds are the last living dinosaurs. Less well known is that whales are the last living whales.",
    "Whales find it difficult to use cutlery.",
    "A whale once played the violin but nobody heard it because it lives in the ocean.",
    "Whales make poor companion pets for house cats.",
    "Apple's interface guidelines for iOS are deliberately, and some would say unfairly, exclusive of the user interface requirements of whales.",
    "If you'd like to support whales in living happy, long lives, go to the beach and throw fistfuls of money into the water. They'll get it eventually.",
    "Making friends with whales is easy. They use all major social media platforms.",
    "The Chinese language has no word for \"whale\".",
    "Whales were only discovered in 1976. Before this, they were assumed to be several thousand different Loch Ness Monsters who had somehow escaped from Loch Ness.",
    "Prince's vault of unreleased music contains 4,026 songs about whales.",
    "Whales were invented in Wales. That's not why they're called that, it's just a coincidence.",
    "A Toyota Landcruiser is incapable of carrying a whale.",
    "Contrary to their reputation, whales actually spend relatively little on consumable items in video games.",
    "Whale oil stopped being a vital consumer product after households discovered that, in reality, they had little need to lubricate sea creatures.",
    "The whale population of London is zero.",
    "Most whales cannot drive cars.",
    "Whales would generally prefer people stop saying that they're having \"a whale of a time\". They feel it belittles their lived experiences.",
    "Whales can fly, they just prefer not to.",
    "If you're interested in seeing whales, a great idea is to look in the ocean. There's loads of them there.",
    "Whales have little use for an app such as Budgie Diet, but I don't hold that against them.",
    "In England, whales are called \"splishy-splashy flippy-flappington lumperdink-Joneses\".",
    "Whales are surprisingly low in calories for their size.",
    "Whales are ineligible to become Prime Minister of the United Kingdom.",
    "Due to a clerical error, a whale once served as a member of the Japanese Diet for six months.",
    "Every time you tap the whale facts button, a whale gets its wings. Whales don't need wings so you should probably stop doing that.",
    "Scientists used a centrifuge, a microscope and the Large Hadron Collider to work out that wearing clothing with whales on it makes you 42% more attractive.",
    "Whale sharks, as a combination of whales and sharks, are the most powerful creatures on Earth.",
    "Selling hats for whales was Elon Musk’s second worst business decision to date.",
    "Whales are the largest objects in the world. If you think you once saw something bigger, you are mistaken.",
    "In the _Matrix_ films, the simulated world did not contain whales because modelling their complex behaviour was too computationally expensive for the machines to handle.",
    "A whale has never usurped the throne of Denmark.",
    "Keyser Soze was a whale.",
    "The briefcase in _Pulp Fiction_ actually contained a whale.",
     "If a whale could be summarised as a mathematical equation, it would be so complex that it would have made Stephen Hawking's brain explode.",
    "Whales operate a large global economy based around plankton futures, denominated in “whale yen”.",
    "Jenna Ortega simply cannot be persuaded that orcas are not just really big penguins."]

let buttonTextArray: [String] =
    ["How fascinating",
    "I bet that's true",
    "What amazing creatures",
    "How do I turn this off",
    "Isn't this a dieting app",
    "Delightful",
    "Splendid",
    "wtf I love whales now",
    "How magnificent",
    "Thank you for letting me know",
    "Noted",
    "Wow",
    "Cool",
    "Why did I turn this on",
    "Such marvellous beasts",
    "Wow, I wish I was a whale",
    "Understood"]

struct WhaleFacts: View {
    @Binding var showing: Bool
    @State var whaleFact: String = ""
    @State var buttonText: String = ""
    @State var newOne: String = ""
    @State var usedStrings: [String] = []
    
    var body: some View {
        Text("A whale fact for you! 🐳")
            .font(.title)
            .padding()
        Spacer()
        VStack {
            Spacer()
            Text(.init(whaleFact))
                .multilineTextAlignment(.center)
                .padding()
            Spacer()
            Button("Give me another one")
            {
                usedStrings.append(whaleFact)
                if usedStrings.count > 10 {
                    usedStrings.remove(at: 0)
                }

                
                var noDupes = false
                
                while noDupes == false
                {
                    var thereIsADupe = false
                    newOne = whaleFactsArray.randomElement()!
                    for entry in usedStrings {
                        if newOne == entry {
                            thereIsADupe = true
                        }
                    }
                    if thereIsADupe == false {
                        noDupes = true
                        whaleFact = newOne
                    }
                }
                
                buttonText = buttonTextArray.randomElement()!
            }.padding()
            Button(buttonText)
            {
                showing = false
            }.padding()
            .buttonStyle(.borderedProminent)
        }
        
        .padding()
        
        .onAppear() {
            whaleFact = whaleFactsArray.randomElement()!
            buttonText = buttonTextArray.randomElement()!
        }
    }
}

#Preview {
    struct Preview: View {
        @State var changed: Bool = false

        var body: some View {
            WhaleFacts(showing: $changed)
        }
    }
    
    return Preview()
}
