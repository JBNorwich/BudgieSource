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
import StoreKit

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

private enum MainNavDestination: Hashable { case foodHub, waterPage }

struct BudgetView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.requestReview) private var requestReview

    
    @StateObject var todayLump: TodayLump = TodayLump()
    @State var hkAuthenticationTrigger: Bool = false

    // state vars for various sheets
    @State var showingHelp: Bool = false
    @State var showingWhales: Bool = false
    @State var showAddCalsSheet: Bool = false
    @State var showWaterSheet: Bool = false
    @State var showingDetail: Bool = false
    @State var showingWeightGoalSheet: Bool = false
    @State var showingWeightDetail: Bool = false
    @State var showingWeightLogSheet: Bool = false
    @State var backgroundGradient = CurrentGradient()
    @State private var mainNavDestination: MainNavDestination?
    @State private var showStorageError = dataStore.storeFailedToLoad
    
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
                                mainNavDestination = .waterPage
                            }.backgroundStyle(.regularMaterial)
                                .frame(minHeight: 100)
                        }
                        
                        if !settingsObj.disableWeightFeatures {
                            GroupBox(label: WeightLabelView(showingWeightGoalSheet: $showingWeightGoalSheet, showingLogWeightSheet: $showingWeightLogSheet)) {
                                WeightView(showingWeightGoalSheet: $showingWeightGoalSheet).environmentObject(todayLump)
                            }.backgroundStyle(.regularMaterial)
                                .frame(minHeight: 100)
                                .onTapGesture {
                                    showingWeightDetail = true
                                }
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
                            mainNavDestination = .foodHub
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
                            NavigationLink(destination: SettingsView()
                                .environmentObject(todayLump)
                                .onDisappear {
                                    // Settings (units, cap, deficit…) feed straight into the lump's
                                    // calculations and display, so recompute on the way out.
                                    Task { await dataStore.updateLump(todayLump: todayLump) }
                                }
                            ) {
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
                            if !settingsObj.disableWeightFeatures {
                                NavigationLink(destination: WeightHistoryView().environmentObject(todayLump)) {
                                    Image(systemName: "scalemass.fill")
                                }.foregroundColor(backgroundGradient.buttonColour)
                            }
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
                    await dataStore.updateLump(todayLump: todayLump)
                }

            }
            .alert("Storage problem", isPresented: $showStorageError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("I couldn't open my database, so anything you log may not be saved. Please restart the app; if this keeps happening, restart your device.")
            }
            
            .navigationDestination(item: $mainNavDestination) { destination in
                switch destination {
                case .foodHub:
                    FoodHub(curDate: Date()).environmentObject(todayLump)
                case .waterPage:
                    WaterPage(curDate: Date()).environmentObject(todayLump)
                }
            }
        }
        
        .onChange(of: scenePhase) {
            guard scenePhase == .active else { return }
            updateGradient()
            Task {
                await dataStore.updateLump(todayLump: todayLump)
                await dataStore.reconcileHealthKit()
            }
            
            // Ask for a review on the user's 3rd distinct day (only once, never during setup).
            if !settingsObj.isFirstRun, ReviewPrompt.registerUseAndShouldPrompt() {
                ReviewPrompt.markRequested()
                Task {
                    try? await Task.sleep(for: .seconds(2))   // let the screen settle first
                    requestReview()
                }
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
                ScrollView {
                    VStack {
                        NewDataView().environmentObject(todayLump)
                        Button("Close") {
                            showingDetail = false
                        }.padding()
                        .buttonStyle(.borderedProminent)
                    }.padding()
                }
                .navigationTitle("Today in detail")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        
        .sheet(isPresented: $showingWeightGoalSheet, onDismiss: { Task { await dataStore.updateLump(todayLump: todayLump)}}) {
            NavigationStack {
                WeightGoalSheet(isDisplayed: $showingWeightGoalSheet)
                    .environmentObject(todayLump)
            }.presentationDetents([.medium])
        }
        
        .sheet(isPresented: $showingWeightDetail) {
            NavigationStack {
                WeightDetailsSheet()
                    .environmentObject(todayLump)
            }.presentationDetents([.medium])
        }
        
        .sheet(isPresented: $showingWeightLogSheet, onDismiss: { Task { await dataStore.updateLump(todayLump: todayLump)}}) {
            NavigationStack {
                LogWeightSheet(isDisplayed: $showingWeightLogSheet)
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
            
            // One-time tour for users who've just finished setup — the "Can eat now: 0" figure is baffling without it. Uses the previously-dormant flag.
            if !settingsObj.isFirstRun && !settingsObj.shownExplainer {
                settingsObj.shownExplainer = true
                showingHelp = true
            }
            
            await dataStore.reconcileHealthKit()
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

struct WeightLabelView: View {
    @Binding var showingWeightGoalSheet: Bool
    @Binding var showingLogWeightSheet: Bool
    
    var body: some View {
        HStack {
            Label("Weight", systemImage: "figure")
            Spacer()
            HStack {
                Button("Goal", systemImage: "target") {
                    showingWeightGoalSheet = true
                }.buttonStyle(.plain)
                Button("Log", systemImage: "plus") {
                    showingLogWeightSheet = true
                }.buttonStyle(.plain)
            }
        }
    }
}

#Preview {
//    BudgetView()
}
