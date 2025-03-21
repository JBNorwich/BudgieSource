//
//  ContentView.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 19/08/2024.
//

import SwiftUI
import HealthKitUI
import Observation

struct currentGradient {
    var backgroundGradient: LinearGradient
    var buttonColour: Color
    
    init() {
        self.backgroundGradient = LinearGradient(
            colors: [Color.black, Color.blue],
            startPoint: .top, endPoint: .bottom)
        self.buttonColour = .black
    }
}

struct WhiteButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
    }
}

struct BlackButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.black)
    }
}

struct BudgetView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) var colorScheme
    
    @State var todayLump: TodayLump = TodayLump()
    @State var dataStore: HealthData = HealthData()
    
    @State var hkAuthenticated: Bool = false
    @State var hkAuthenticationTrigger: Bool = false

    @State var firstRun = Bool()

    // state vars for various sheets
    @State var showingHelp: Bool = false
    @State var showingWhales: Bool = false
    @State var openingFoodHub: Bool = false
    @State var showAddCalsSheet: Bool = false
    @State var showWaterSheet: Bool = false
    
    // this is needed because otherwise it won't update state when returning from settings
    @State var whaleButtonVisible: Bool = false
    
    @State var backgroundGradient = currentGradient()

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
                            MeterView(todayLump: $todayLump, dummy: false)
                                .padding()
                            
                                .onTapGesture {
                                    Task {
                                        dataStore.lastUpdateRequestSource = "Tap on blob"
                                        dataStore.dataUpdated = true
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
                            GaugeView(dataLump: $todayLump)
                        }.backgroundStyle(.regularMaterial)
                        if settingsObj.manualMode != true {
                            HStack {
                                GroupBox(label: Label("Fitness", systemImage:"figure.run")) {
                                    FitnessView(todayLump: $todayLump)
                                }.backgroundStyle(.regularMaterial)
                                    .frame(minHeight: 100)
                                GroupBox(label: WaterLabelView(showingWaterSheet: $showWaterSheet)) {
                                    WaterView(todayLump: $todayLump)
                                }.backgroundStyle(.regularMaterial)
                                    .frame(minHeight: 100)
                            }
                        }
                        if settingsObj.hideTodayInDetail != true {
                            GroupBox(label: Label("Today in detail", systemImage:"sun.max")) {
                                NewDataView(dataLump: $todayLump)
                            }.backgroundStyle(.regularMaterial)
                        }
                        GroupBox(label: FoodListLabelView(showingAddCalsSheet: $showAddCalsSheet))
                        {
                            TodayFoodList(dataLump: $todayLump)
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
                            NavigationLink(destination: SettingsView(dataStore: $dataStore, todayLump: $todayLump, whale: $whaleButtonVisible)) {
                                Image(systemName: "gear")
                            }.foregroundColor(backgroundGradient.buttonColour)
                            if settingsObj.whalesEverywhere == true {
                                Button("🐳") {
                                    showingWhales = true
                                }
                            }
                        }
                        
                        ToolbarItemGroup(placement: .topBarTrailing) {

                            NavigationLink(destination: FoodHub(dataObject: $dataStore, todayLump: $todayLump, curDate: Date())) {
                                Image(systemName: "fork.knife")
                            }.foregroundColor(backgroundGradient.buttonColour)
                            NavigationLink(destination: ChartPage(dataStore: $dataStore, todayLump: $todayLump)) {
                                Image(systemName: "chart.xyaxis.line")
                            }.foregroundColor(backgroundGradient.buttonColour)
                            
                            if colorScheme == .dark {
                                Button("Add quick calories", systemImage: "plus") {
                                    showAddCalsSheet = true
                                }.buttonStyle(WhiteButton())
                            } else {
                                Button("Add quick calories", systemImage: "plus") {
                                    showAddCalsSheet = true
                                }.buttonStyle(BlackButton())
                            }
                        }
                    }
                }
                .navigationTitle("Today")
                .padding(.horizontal)
                .toolbarBackground(.clear, for: .automatic)
                .refreshable {
                    dataStore.lastUpdateRequestSource = "Pull to refresh"
                    dataStore.isBackgroundPing = false
                    dataStore.dataUpdated = true
                }

            }
        }
        
        .navigationDestination(isPresented: $openingFoodHub)
        {
            FoodHub(dataObject: $dataStore, todayLump: $todayLump, curDate: getStartOfDay(date: Date()))
        }
        
        .onChange(of: scenePhase) {
            guard scenePhase == .active else {
               return
            }
            
            switch colorScheme {
            case .dark: backgroundGradient.backgroundGradient = LinearGradient(
                colors: [Color.black, Color.blue],
                startPoint: .top, endPoint: .bottom)
                backgroundGradient.buttonColour = .white
            default: backgroundGradient.backgroundGradient = LinearGradient(
                colors: [Color.cyan, Color.blue],
                startPoint: .top, endPoint: .bottom)
                backgroundGradient.buttonColour = .black
            }
            
            dataStore.lastUpdateRequestSource = "Return of app to foreground"
            dataStore.dataUpdated = true
        }
        
        .onChange(of: colorScheme) {
            switch colorScheme {
            case .dark: backgroundGradient.backgroundGradient = LinearGradient(
                colors: [Color.black, Color.blue],
                startPoint: .top, endPoint: .bottom)
                backgroundGradient.buttonColour = .white
            default: backgroundGradient.backgroundGradient = LinearGradient(
                colors: [Color.cyan, Color.blue],
                startPoint: .top, endPoint: .bottom)
                backgroundGradient.buttonColour = .black
            }
        }
        
        .onChange(of: dataStore.dataUpdated) {
            if dataStore.dataUpdated == true && dataStore.updateInProgress == false {
                if scenePhase != .background {
                    Task {
                        await todayLump = dataStore.produceTodayObject()
                    }
                } else {
                    if dataStore.isBackgroundPing == true {
                        if todayLump.lastUpdate < getHalfHourBefore(date: Date())
                        {
                            Task {
                                await todayLump = dataStore.produceTodayObject()
                            }
                        } else {
                            dataStore.isBackgroundPing = false
                        }
                    } else {
                        Task {
                          await todayLump = dataStore.produceTodayObject()
                        }
                    }
                }
            }
        }
        
        .onAppear() {
            firstRun = settingsObj.isFirstRun
            dataStore.lastUpdateRequestSource = "Initial start"
            dataStore.dataUpdated = true
            
            switch colorScheme {
            case .dark: backgroundGradient.backgroundGradient = LinearGradient(
                colors: [Color.black, Color.blue],
                startPoint: .top, endPoint: .bottom)
                backgroundGradient.buttonColour = .white
            default: backgroundGradient.backgroundGradient = LinearGradient(
                colors: [Color.cyan, Color.blue],
                startPoint: .top, endPoint: .bottom)
                backgroundGradient.buttonColour = .black
            }
            
            if firstRun != true {
                if HKHealthStore.isHealthDataAvailable() {
                    hkAuthenticationTrigger.toggle()
                }
            }
        
            whaleButtonVisible = settingsObj.whalesEverywhere
        }
                    
        .healthDataAccessRequest(store: healthStore, shareTypes: writeTypes, readTypes: readTypes, trigger: hkAuthenticationTrigger) { result in
            switch result {
            case .success(_):
                hkAuthenticated = true
            case .failure(_):
                print("Failed for some reason")
            }
        }
        
        .sheet(isPresented: $showAddCalsSheet) {
            NavigationStack {
                AddCalsSheet(dataStore: $dataStore, isDisplayed: $showAddCalsSheet, curEaten: todayLump.eatenCalories, remBudg: todayLump.totalBudgetRem, selectedDate: Date())
            }
            .presentationDetents([.medium,.large])
        }
        
        .sheet(isPresented: $showingWhales) {
            NavigationStack {
                WhaleFacts(showing: $showingWhales)
            }
            .presentationDetents([.medium])
        }
        
        .sheet(isPresented: $firstRun) {
            FirstRunSheet(isPresented: $firstRun, settingsObj: settingsObj, dataStore: dataStore)
                .onDisappear {
                    showingHelp = true
                }
        }
        
        .sheet(isPresented: $showingHelp) {
            Explainer(showing: $showingHelp)
        }
        
        .sheet(isPresented: $showWaterSheet) {
            NavigationStack {
                AddWaterSheet(dataStore: $dataStore, isDisplayed: $showWaterSheet)
            }
            .presentationDetents([.medium])
        }
            
        .task() {
            if settingsObj.manualMode != true {
                dataStore.setUpObserverQueries()
            }
            todayLump = await dataStore.produceTodayObject()
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

#Preview {
    BudgetView()
}
