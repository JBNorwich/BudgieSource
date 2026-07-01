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
import HealthKitUI
import Observation

struct CurrentGradient {
    var backgroundGradient: LinearGradient
    var buttonColour: Color
    
    init() {
        self.backgroundGradient = LinearGradient(
            colors: [Color.black, Color.blue],
            startPoint: .top, endPoint: .bottom)
        self.buttonColour = .black
    }
}

struct ColoredButton: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.foregroundStyle(color)
    }
}

struct BudgetView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) var colorScheme
    
    @StateObject var todayLump: TodayLump = TodayLump()
    @State var hkAuthenticationTrigger: Bool = false

    // state vars for various sheets
    @State var showingHelp: Bool = false
    @State var showingWhales: Bool = false
    @State var openingFoodHub: Bool = false
    @State var openingWaterPage: Bool = false
    @State var showAddCalsSheet: Bool = false
    @State var showWaterSheet: Bool = false
    @State var showingDetail: Bool = false
    @State var showingWeightSheet: Bool = false
    @State var showingWeightDetail: Bool = false
    @State var showingFirstRun: Bool = false
    @State var backgroundGradient = CurrentGradient()
    
    func updateGradient() {
        switch colorScheme {
        case .dark:
            backgroundGradient.backgroundGradient = LinearGradient(colors: [.black, .blue], startPoint: .top, endPoint: .bottom)
            backgroundGradient.buttonColour = .white
        default:
            backgroundGradient.backgroundGradient = LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom)
            backgroundGradient.buttonColour = .black
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient.backgroundGradient
                    .ignoresSafeArea()
                    .safeAreaInset(edge: .bottom) {
                        HStack {
                            Image("Budgie")
                                .resizable()
                                .frame(maxWidth: 116,maxHeight: 100)
                            Text(getBudgieGreeting())
                            Spacer()
                        }.offset(x: 0, y: 50)
                    }
                ScrollView {
                    VStack {
                        ZStack{
                            Circle()
                                .foregroundStyle(.thinMaterial)
                            MeterView(dummy: false)
                                .environmentObject(todayLump)
                                .padding()
                                .onTapGesture {
                                    Task {
                                        await dataStore.updateLump(todayLump: todayLump)
                                    }
                                }
                            
                        }.frame(maxHeight: 275)
                            .overlay {
                                VStack {
                                    HStack {
                                        Spacer()
                                        Button("", systemImage: "questionmark.circle"){
                                            showingHelp = true
                                        }.frame(minHeight: 44)
                                    }
                                    Spacer()
                                }
                                .padding()
                            }.padding()
                        Spacer()
                        GroupBox(label: Label("Your target", systemImage: "gauge.with.needle")) {
                            GaugeView().environmentObject(todayLump)
                        }.backgroundStyle(.regularMaterial)
                            .onTapGesture {
                                showingDetail = true
                            }
                        HStack {
                            GroupBox(label: Label("Activity", systemImage:"figure.run")) {
                                FitnessView().environmentObject(todayLump)
                            }.onTapGesture {
                                UIApplication.shared.open(URL(string: "fitnessapp://")!)
                            }.backgroundStyle(.regularMaterial)
                                .frame(minHeight: 100)
                            GroupBox(label: WaterLabelView(showingWaterSheet: $showWaterSheet)) {
                                WaterView().environmentObject(todayLump)
                            }.onTapGesture {
                                openingWaterPage = true
                            }.backgroundStyle(.regularMaterial)
                                .frame(minHeight: 100)
                        }
                        
                        GroupBox(label: WeightLabelView(showingWeightGoalSheet: $showingWeightSheet)) {
                            WeightView().environmentObject(todayLump)
                        }.backgroundStyle(.regularMaterial)
                            .frame(minHeight: 100)
                            .onTapGesture {
                                showingWeightDetail = true
                            }
                        
                        if settingsObj.hideTodayInDetail != true {
                            GroupBox(label: Label("Today in detail", systemImage:"sun.max")) {
                                NewDataView().environmentObject(todayLump)
                            }.backgroundStyle(.regularMaterial)
                        }
                        GroupBox(label: FoodListLabelView(showingAddCalsSheet: $showAddCalsSheet))
                        {
                            TodayFoodList().environmentObject(todayLump)
                        }.onTapGesture {
                            openingFoodHub = true
                        }.backgroundStyle(.regularMaterial)
                        
                        HStack {
                            Text("Last updated: " + todayLump.lastUpdate.formatted())
                                .padding()
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        VStack{
                            Rectangle()
                                .foregroundStyle(.clear)
                                .frame(minHeight: 35)
                        }
                    }
                    
                    .toolbar {
                        ToolbarItemGroup(placement: .topBarLeading) {
                            NavigationLink(destination: SettingsView().environmentObject(todayLump)) {
                                Image(systemName: "gear")
                            }.foregroundColor(backgroundGradient.buttonColour)
                            if settingsObj.whalesEverywhere == true {
                                Button("🐳") {
                                    showingWhales = true
                                }
                            }
                        }
                        
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            NavigationLink(destination: FoodHub(curDate: Date()).environmentObject(todayLump)) {
                                Image(systemName: "fork.knife")
                            }.foregroundColor(backgroundGradient.buttonColour)
                            NavigationLink(destination: WaterPage(curDate: Date()).environmentObject(todayLump)) {
                                Image(systemName: "drop.fill")
                            }.foregroundColor(backgroundGradient.buttonColour)
                            NavigationLink(destination: ChartPage().environmentObject(todayLump)) {
                                Image(systemName: "chart.xyaxis.line")
                            }.foregroundColor(backgroundGradient.buttonColour)
                            
                            Button("Add quick calories", systemImage: "plus") {
                                showAddCalsSheet = true
                            }.buttonStyle(ColoredButton(color: backgroundGradient.buttonColour))
                        }
                    }
                }
                .navigationTitle("Today")
                .padding(.horizontal)
                .toolbarBackground(.clear, for: .automatic)
                .refreshable {
                    Task {
                        await dataStore.updateLump(todayLump: todayLump)
                    }
                }

            }
        }
        
        .navigationDestination(isPresented: $openingFoodHub)
        {
            FoodHub(curDate: Date()).environmentObject(todayLump)
        }
        
        .navigationDestination(isPresented: $openingWaterPage)
        {
            WaterPage(curDate: Date()).environmentObject(todayLump)
        }
        
        .onChange(of: scenePhase) {
            guard scenePhase == .active else {
               return
            }
            updateGradient()
            Task {
                await dataStore.updateLump(todayLump: todayLump)
            }
        }
        
        .onChange(of: colorScheme) {
            updateGradient()
        }
        
        .onAppear() {
            updateGradient()
            if !settingsObj.isFirstRun {
                if HKHealthStore.isHealthDataAvailable() {
                    hkAuthenticationTrigger.toggle()
                }
            }
        }
                    
        .healthDataAccessRequest(store: healthStore, shareTypes: writeTypes, readTypes: readTypes, trigger: hkAuthenticationTrigger) { result in
            switch result {
            case .success(_):
                print("HealthKit is authenticated")
            case .failure(_):
                print("Failed for some reason")
            }
        }
        
        .sheet(isPresented: $showAddCalsSheet) {
            NavigationStack {
                AddCalsSheet(isDisplayed: $showAddCalsSheet, selectedDate: Date()).environmentObject(todayLump)
            }
            .presentationDetents([.medium,.large])
        }
        
        .sheet(isPresented: $showingWhales) {
            NavigationStack {
                WhaleFacts(showing: $showingWhales)
            }
            .presentationDetents([.medium])
        }
        
        .sheet(isPresented: $showingFirstRun) {
            FirstRunSheet(isPresented: $showingFirstRun)
                .environmentObject(todayLump)
                .onDisappear {
                    showingHelp = true
                }
        }
        
        .sheet(isPresented: $showingHelp) {
            Explainer(showing: $showingHelp).environmentObject(todayLump)
        }
        
        .sheet(isPresented: $showWaterSheet) {
            // No environment object needs to be passed to AddWaterSheet as that view doesn't do anything with it.
            NavigationStack {
                AddWaterSheet(isDisplayed: $showWaterSheet, dateToAddOn: Date())
            }
            .presentationDetents([.medium])
            .onDisappear() {
                Task {
                    await dataStore.updateLump(todayLump: todayLump)
                }
            }
        }
        
        .sheet(isPresented: $showingDetail) {
            NavigationStack {
                VStack {
                    NewDataView().environmentObject(todayLump)
                    Button("Close") {
                        showingDetail = false
                    }.padding()
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }.padding()
                .navigationTitle("Today in detail")
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        
        .sheet(isPresented: $showingWeightSheet) {
            NavigationStack {
                WeightGoalSheet(isDisplayed: $showingWeightSheet)
                    .environmentObject(todayLump)
            }.presentationDetents([.medium])
        }.onDisappear() {
            Task {
                await dataStore.updateLump(todayLump: todayLump)
            }
        }
        
        .sheet(isPresented: $showingWeightDetail) {
            NavigationStack {
                WeightDetailsSheet()
                    .environmentObject(todayLump)
            }.presentationDetents([.medium])
        }
            
        .task() {
            dataStore.setUpObserverQueries(todayLump: todayLump)
            dataStore.setUpRemoteChangeObserver(todayLump: todayLump)
            await dataStore.updateLump(todayLump: todayLump)
            if settingsObj.isFirstRun != true {
                if settingsObj.startWeight == 0 {
                    settingsObj.startWeight = todayLump.weightToday
                }
            }
        }
    }
}

struct FoodListLabelView: View {
    @Binding var showingAddCalsSheet: Bool
    
    var body: some View {
        HStack{
            Label("Eaten today", systemImage: "fork.knife")
            Spacer()
            Button ("Add food", systemImage: "plus") {
                showingAddCalsSheet = true
            }.buttonStyle(.plain)
        }
    }
}

struct WaterLabelView: View {
    @Binding var showingWaterSheet: Bool
    
    var body: some View {
        HStack{
            Label("Water", systemImage: "drop.fill")
            Spacer()
            Button ("Add", systemImage: "plus") {
                showingWaterSheet = true
            }.buttonStyle(.plain)
        }
    }
}

struct ActivityLabelView: View {
    var body: some View {
        HStack{
            Label("Activity", systemImage: "figure.run")
            Spacer()
        }
    }
}

struct WeightLabelView: View {
    @Binding var showingWeightGoalSheet: Bool
    
    var body: some View {
        HStack {
            Label("Weight", systemImage: "figure")
            Spacer()
            Button("Goal", systemImage: "target") {
                showingWeightGoalSheet = true
            }.buttonStyle(.plain)
        }
    }
}

#Preview {
//    BudgetView()
}
