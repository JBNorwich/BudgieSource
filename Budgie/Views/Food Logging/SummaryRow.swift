//
//  SummaryRow.swift
//  Budgie
//
//  Created by Joe Baldwin on 26/08/2024.
//

import SwiftUI

struct SummaryRow: View {
    let dateFormatter = DateFormatter()
    var dataLump: ChartDataLump
    var curDate: Date
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
                        Text(negate(number: dataLump.deficit).formatted())
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
                            Text(negate(number: assessDeficit(desired: settingsObj.desiredDeficit, actual: dataLump.deficit).offTarget).formatted())
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
            
            .onAppear() {
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
