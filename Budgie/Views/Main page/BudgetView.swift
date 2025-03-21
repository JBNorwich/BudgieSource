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
    
    @StateObject var todayLump: TodayLump = TodayLump()
    
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
                        if settingsObj.manualMode != true {
                            HStack {
                                GroupBox(label: Label("Fitness", systemImage:"figure.run")) {
                                    FitnessView().environmentObject(todayLump)
                                }.backgroundStyle(.regularMaterial)
                                    .frame(minHeight: 100)
                                GroupBox(label: WaterLabelView(showingWaterSheet: $showWaterSheet)) {
                                    WaterView().environmentObject(todayLump)
                                }.backgroundStyle(.regularMaterial)
                                    .frame(minHeight: 100)
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
                            NavigationLink(destination: SettingsView(whale: $whaleButtonVisible).environmentObject(todayLump)) {
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
                            NavigationLink(destination: ChartPage().environmentObject(todayLump)) {
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
            
            Task {
                await dataStore.updateLump(todayLump: todayLump)
            }
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
        
        .onAppear() {
            firstRun = settingsObj.isFirstRun
            
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
        
        .sheet(isPresented: $firstRun) {
            FirstRunSheet(isPresented: $firstRun)
                .onDisappear {
                    showingHelp = true
                }
        }
        
        .sheet(isPresented: $showingHelp) {
            Explainer(showing: $showingHelp).environmentObject(todayLump)
        }
        
        .sheet(isPresented: $showWaterSheet) {
            NavigationStack {
                AddWaterSheet(isDisplayed: $showWaterSheet)
            }
            .presentationDetents([.medium])
        }
            
        .task() {
            if settingsObj.manualMode != true {
                dataStore.setUpObserverQueries(todayLump: todayLump)
            }
            await dataStore.updateLump(todayLump: todayLump)
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
