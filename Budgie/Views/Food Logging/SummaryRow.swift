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

struct SummaryRow: View {
    let dateFormatter = DateFormatter()
    var dataLump: ChartDataLump
    @Binding var curDate: Date
    @State var formDate: String = ""

    var body: some View {
        VStack {
            HStack {
                VStack {
                    Text(getFullDayOfWeek(date: dataLump.date))
                    Text(formDate)
                        .font(.title)
                        .fontWeight(/*@START_MENU_TOKEN@*/.bold/*@END_MENU_TOKEN@*/)
                }.frame(minWidth: 70)
                VStack {
                    HStack {
                        Text("CALS IN")
                            .font(.caption)
                        Spacer()
                        Text(dataLump.eatenCals.formatted())
                            .font(.caption)
                    }
                    HStack {
                        Text("CALS OUT")
                            .font(.caption)
                        Spacer()
                        Text(dataLump.totalCals.formatted())
                            .font(.caption)
                    }
                    Divider()
                    HStack {
                        
                        if dataLump.deficit < 0 {
                            Text("SURPLUS")
                                .font(.caption)
                                .fontWeight(.bold)
                        } else {
                            Text("DEFICIT")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        Text((-dataLump.deficit).formatted())
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                }.minimumScaleFactor(0.1)
                    .scaledToFill()
                    .padding()
                VStack {
                    Text(assessDeficit(desired: settingsObj.desiredDeficit, actual: dataLump.deficit).narrative)
                        .font(.caption)
                        .minimumScaleFactor(0.1)
                        .scaledToFit()
                    HStack {
                        if assessDeficit(desired: settingsObj.desiredDeficit, actual: dataLump.deficit).offTarget == 0 {
                            Image(systemName: "arrow.right")
                        } else if assessDeficit(desired: settingsObj.desiredDeficit, actual: dataLump.deficit).offTarget < 0 {
                            Image(systemName: "arrow.up")
                        } else {
                            Image(systemName: "arrow.down")
                        }
                        if assessDeficit(desired: settingsObj.desiredDeficit, actual: dataLump.deficit).offTarget < 0 {
                            Text((-assessDeficit(desired: settingsObj.desiredDeficit, actual: dataLump.deficit).offTarget).formatted())
                                .font(.title)
                                .minimumScaleFactor(0.5)
                                .scaledToFit()
                        } else {
                            Text(assessDeficit(desired: settingsObj.desiredDeficit, actual: dataLump.deficit).offTarget.formatted())
                                .font(.title)
                                .minimumScaleFactor(0.5)
                                .scaledToFit()
                        }
                    }
                }.frame(minWidth: 105, maxWidth: 105)
            }

            .onChange(of: curDate, initial: true)
            {
                dateFormatter.dateFormat = "dd/MM"
                formDate = curDate.formatted(date: .numeric, time: .omitted)
                formDate = String(formDate.dropLast(5))
            }
        }
    }
}

//#Preview {
//    SummaryRow()
//}
