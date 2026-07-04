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

struct MacBudgetHelperView: View {
    @Binding var isPresented: Bool
    @State private var show1000Warning = false

    private struct Preset { let title, detail, note: String; let deficit: Int }

    private var presets: [Preset] {
        let m = settingsObj.impMetric == 0
        return [
            Preset(title: "No deficit", detail: "Maintain your current weight", note: "Choose this to hold steady.", deficit: 0),
            Preset(title: "Easy — 250 kcal/day", detail: m ? "≈ 225 g a week · a chocolate bar" : "≈ ½ lb a week · a chocolate bar", note: "Most people find this easy to stick to.", deficit: 250),
            Preset(title: "Moderate — 500 kcal/day", detail: m ? "≈ 450 g a week · two cupcakes" : "≈ 1 lb a week · two cupcakes", note: "A good starting point for most people.", deficit: 500),
            Preset(title: "Hard — 750 kcal/day", detail: m ? "≈ 700 g a week · half a roast chicken" : "≈ 1½ lb a week · half a roast chicken", note: "Best if you exercise a lot or have a lot to lose.", deficit: 750),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Choose a goal").font(.title2).bold()
                Spacer()
                Button("Cancel") { isPresented = false }
            }.padding()
            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(presets, id: \.deficit) { p in
                        card(title: p.title, detail: p.detail, note: p.note, tint: .primary) {
                            settingsObj.desiredDeficit = p.deficit
                            isPresented = false
                        }
                    }
                    card(title: "Very hard — 1,000 kcal/day",
                         detail: "",
                         note: "Only appropriate with a significant amount to lose, and even then it can be hard to get enough energy and nutrients. If unsure, talk to your doctor first.",
                         tint: .red, bordered: true) { show1000Warning = true }

                    Text(.init(healthDisclaimer))
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.top, 8)
                }.padding()
            }
        }
        .frame(width: 480, height: 580)
        .sheet(isPresented: $show1000Warning) {
            ThousandKcalWarningSheet(isDisplayed: $show1000Warning,
                onConfirm: { settingsObj.desiredDeficit = 1000; isPresented = false })
                .frame(width: 420).padding()
        }
    }

    @ViewBuilder
    private func card(title: String, detail: String, note: String, tint: Color,
                      bordered: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline).foregroundStyle(tint)
                if !detail.isEmpty { Text(detail).font(.subheadline) }
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay { if bordered { RoundedRectangle(cornerRadius: 10).stroke(.red.opacity(0.4)) } }
        }
        .buttonStyle(.plain)
    }
}
