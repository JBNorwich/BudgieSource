//
//  BudgieWidget.swift
//  BudgieWidget
//
//  Created by Joe Baldwin on 01/09/2024.
//

import WidgetKit
import SwiftUI
import HealthKit

let settingsObj = UserSettings()
let healthStore = HKHealthStore()

struct TinyMeter: View {
    var leftToEat: Int
    var progress: Double
    var totalBudg: Int
    var projBasal: Int
    @State var blobColour: Color = .clear
    @State var pathColour: Color = .clear
    
    func getBlobColour(input: Int) -> Color
    {
        var returnColor: Color = .teal
        if input < -49
        {
            switch settingsObj.surplusMode {
            case true: returnColor = .green
            case false : returnColor = .red
            }
        } else if input < 50 {
            switch settingsObj.surplusMode {
            case true: returnColor = .red
            case false: returnColor = .green
            }
        }
        return returnColor
    }
    
    func getPathColour() -> Color
    {
        let reallyGoodColor = (Color.blue)
        let goodColour = Color(.systemGreen)
        let okColour = Color(.systemYellow)
        let badColour = Color(.systemRed)
        
        let diff = progress / getPercentOfDayDone()
        
        if diff < 0.25 {
            return reallyGoodColor
        } else if diff < 1.05 {
            return goodColour
        } else if diff < 1.20 {
            if (diff - 1) * Double(totalBudg) < Double(projBasal) {
                return goodColour
            } else {
                return okColour
            }
        } else {
            return badColour
        }
    }

    var body: some View {
        ZStack {
                Circle()
                    .fill(.shadow(.drop(color: .black, radius: 4)))
                    .fill(getBlobColour(input: leftToEat))
                Circle()
                    .trim(from: 0, to: progress)
                    .rotation(Angle(degrees: -90))
                    // GOES CLOCKWISE FROM EAST
                    .fill(.clear)
                    .stroke(getPathColour().gradient, style:StrokeStyle(lineWidth: 10, lineCap: .round))
                    .shadow(radius: 10)
                    .shadow(radius: 5)
                Text(leftToEat.formatted())
                    .fontWeight(.heavy)
                    .font(.system(size:14))
                    .minimumScaleFactor(0.01)
                    .scaledToFit()
                    .contentMargins(50)
                    .contentTransition(.numericText())
                    .shadow(radius: 5)
                    .foregroundColor(.white)
            }
        }
    }

struct Provider: TimelineProvider {
    var lump = TodayLump()
    
    func placeholder(in context: Context) -> BudgieEntry {
        BudgieEntry(date: Date(), leftToEat: 428, progressDbl: 0.75, totalBudgRem: 890, totalBudg: 3560, projBasal: 2000)
    }

    func getSnapshot(in context: Context, completion: @escaping (BudgieEntry) -> ()) {
        let entry = BudgieEntry(date: Date(), leftToEat: 428, progressDbl: 0.75, totalBudgRem: 890, totalBudg: 3560, projBasal: 2000)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task {
            let dataStore = HealthData()
            let lump = await dataStore.produceTodayObject()
            let date = Date()
            sleep(4)
            let entry = BudgieEntry(date: date, leftToEat: lump.leftToEat, progressDbl: lump.progressToday, totalBudgRem: lump.totalBudgetRem, totalBudg: lump.totalBudget, projBasal: lump.projectedBasal)
            
            let nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 30, to: date)!
            
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdateDate))
            
            completion(timeline)
        }
    }
}

struct BudgieEntry: TimelineEntry {
    let date: Date
    let leftToEat: Int
    let progressDbl: Double
    let totalBudgRem: Int
    let totalBudg: Int
    let projBasal: Int
}

struct BudgieWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        ZStack {
            VStack {
                Spacer()
                HStack {
                    Image("Budgie")
                        .resizable()
                        .frame(maxWidth: 58, maxHeight: 50)
                        .offset(x: -25, y: 25)
                    Spacer()
                }
            }
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    TinyMeter(leftToEat: entry.leftToEat, progress: entry.progressDbl, totalBudg: entry.totalBudg, projBasal: entry.projBasal)
                        .frame(maxWidth: 50, maxHeight: 50)
                }
            }
            VStack {
                VStack {
                    HStack {
                        Text("Can eat now".uppercased())
                            .font(.caption)
                        Spacer()
                    }
                    HStack {
                        Text(entry.leftToEat.formatted())
                            .font(.title)
                        Spacer()
                    }
                    HStack {
                        Text("Budget left".uppercased())
                            .font(.caption)
                        Spacer()
                    }
                    HStack {
                        if entry.totalBudgRem > -1 {
                            Text(entry.totalBudgRem.formatted())
                        } else {
                            Text(negate(value: entry.totalBudgRem).formatted())
                                .font(.title)
                        }
                        
                        Spacer()
                    }
                    Spacer()
                    
                    
                }
            }
        }
    }
}

/// Widget view for `accessoryCircular`
struct CircularWidgetView: View {
    let entry: BudgieEntry
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AccessoryWidgetBackground()
                VStack {
                    Gauge(value: entry.progressDbl) {
                        Text(verbatim: entry.leftToEat.formatted())
                    }.gaugeStyle(.accessoryCircularCapacity)
                }
            }
            .containerBackground(for: .widget) { }
        }
    }
}

struct ViewSizeWidgetView: View {
    let entry: BudgieEntry
    
    let gradient = LinearGradient(
        colors: [Color.cyan, Color.blue],
        startPoint: .top, endPoint: .bottom)

    // Obtain the widget family value
    @Environment(\.widgetFamily)
    var family

    var body: some View {

        switch family {
        case .accessoryCircular:
            CircularWidgetView(entry: entry)
        default:
            // UI for Home Screen widget
            BudgieWidgetEntryView(entry: entry)
                .containerBackground(gradient, for: .widget)
        }
    }
}

struct BudgieWidget: Widget {
    let kind: String = "BudgieWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ViewSizeWidgetView(entry: entry)
        }
        .configurationDisplayName("Current status")
        .description("This shows your current budget status.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

#Preview(as: .systemSmall) {
    BudgieWidget()
} timeline: {
    BudgieEntry(date: Date(), leftToEat: 428, progressDbl: 0.75, totalBudgRem: 890, totalBudg: 3560, projBasal: 2000)
}
