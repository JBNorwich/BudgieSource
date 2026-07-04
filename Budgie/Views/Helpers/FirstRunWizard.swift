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

struct FirstRunWizard: View {
    /// Flipped to `false` once setup finishes, which crossfades to `BudgetView`.
    @Binding var needsSetup: Bool

    // The wizard is the app's root during first run, so it owns its own lump.
    @StateObject private var todayLump = TodayLump()

    enum Step: Int, CaseIterable, Comparable {
        case welcome, healthKit, logWeight, bmr, goal, calorieTarget, goalWeight, done
        static func < (a: Step, b: Step) -> Bool { a.rawValue < b.rawValue }
    }
    @State private var step: Step = .welcome

    // Per-step working state.
    @State private var hkPermsToggle = false
    @State private var manualBMR = 0
    @State private var manualActive = 0
    @State private var chosenGoal = 0
    @State private var goalChosen = false
    @State private var desiredSurplus: Double = 50
    @State private var disclaimerOn = false
    @State private var weightUnit = settingsObj.weightDisplayUnit
    
    @State private var stepsTaken: [Step] = []
    @State private var hkFailed = false
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var backgroundGradient = CurrentGradient()

    private func go(to newStep: Step) {
        stepsTaken.append(step)
        withAnimation(.easeInOut) { step = newStep }
    }

    private func goBack() {
        guard let previous = stepsTaken.popLast() else { return }
        withAnimation(.easeInOut) { step = previous }
    }
    
    // Mirrors BudgetView's gradient so the wizard matches light/dark mode.
    private func updateGradient() {
        switch colorScheme {
        case .dark:
            backgroundGradient.backgroundGradient = LinearGradient(colors: [.black, .blue], startPoint: .top, endPoint: .bottom)
            backgroundGradient.buttonColour = .white
        default:
            backgroundGradient.backgroundGradient = LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom)
            backgroundGradient.buttonColour = .black
        }
    }

    /// The embedded helper views (BMRHelper, BudgetHelperView, WeightGoalSheet) all
    /// report completion by setting their presentation binding to `false`. We hand
    /// them a binding that treats that as "advance to the next step", so they can be
    /// shown inline instead of as sheets.
    private func completion(advancingTo next: Step) -> Binding<Bool> {
        Binding(get: { true }, set: { stillPresented in
            if !stillPresented { go(to: next) }
        })
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
                                .frame(maxWidth: 116, maxHeight: 100)
                            Spacer()
                        }
                        .offset(x: 0, y: 50)
                    }

                VStack(spacing: 0) {
                    progressBar
                    Divider()

                    Group {
                        switch step {
                            case .welcome:       welcomeScreen
                            case .healthKit:     healthKitScreen
                            case .logWeight:     logWeightScreen
                            case .bmr:           bmrScreen
                            case .goal:          goalScreen
                            case .calorieTarget: calorieTargetScreen
                            case .goalWeight:    goalWeightScreen
                            case .done:          doneScreen
                        }
                    }
                    .id(step)
                    .transition(.asymmetric(insertion: .move(edge: .trailing),
                                            removal: .move(edge: .leading)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(step == .welcome ? "Welcome to Budgie Diet!" : "Set up Budgie Diet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.clear, for: .automatic)
        }
        .onAppear { updateGradient() }
        .onChange(of: colorScheme) { updateGradient() }
        // …existing .healthDataAccessRequest modifier stays exactly as-is, after this…
        // HealthKit request stays attached to the always-present container.
        .healthDataAccessRequest(store: healthStore,
                                 shareTypes: writeTypes,
                                 readTypes: readTypes,
                                 trigger: hkPermsToggle) { result in
            switch result {
            case .success:
                Task { @MainActor in
                    // Populate the lump; updateLump already runs getLatestWeight() for us.
                    await dataStore.updateLump(todayLump: todayLump)
                    if todayLump.lastWeightDate != nil, todayLump.weightToday > 0 {
                        // There's a recent HealthKit weight — reuse it in the BMR step.
                        settingsObj.weight = Int(todayLump.weightToday.rounded())
                        go(to: .bmr)
                    } else {
                        // Nothing recorded — ask the user to log a weight first.
                        go(to: .logWeight)
                    }
                }
            case .failure:
                hkFailed = true
            }
        }
    }

    // MARK: - Progress

    private var progressBar: some View {
        HStack(spacing: 8) {
            Button {
                goBack()
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(stepsTaken.isEmpty)
            .opacity(stepsTaken.isEmpty ? 0 : 1)
            .accessibilityLabel("Back")
            ForEach(Step.allCases, id: \.self) { s in
                Capsule()
                    .frame(height: 4)
                    .foregroundStyle(s <= step ? Color.accentColor : Color.secondary.opacity(0.3))
            }
        }
        .padding()
    }

    private var welcomeScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            Image("IconImage")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
                .shadow(radius: 8)
            Text("Let's get you set up!")
                .font(.title).bold()
            Text("Budgie Diet doesn't send your information anywhere, is free, has no ads and doesn't track you.")
                .multilineTextAlignment(.center)
            Link("Privacy policy",
                 destination: URL(string: "https://joebaldwin.me.uk/apps/budgiediet/privacy/")!)

            VStack(spacing: 8) {
                Text("Which units do you use for weight?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("", selection: $weightUnit) {
                    Text("Kilograms").tag(0)
                    Text("Pounds").tag(1)
                    Text("Stone & pounds").tag(2)
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)

            Spacer()
            Button("Get started") { go(to: .healthKit) }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .onChange(of: weightUnit) { settingsObj.weightDisplayUnit = weightUnit }
    }

    private var healthKitScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Connect Apple Health").font(.title2).bold()
            Text("You need to do this to use Budgie Diet, as it lets me assess your recent activity to decide your budgets, log your water and weight, and bring in your data from other apps. It's really important! Please make sure you grant permissions after hitting the button!")
                .multilineTextAlignment(.center)
            Button("Authorise Health access") {
                hkFailed = false
                hkPermsToggle.toggle()
            }
            .buttonStyle(.borderedProminent)
            if hkFailed {
                Text("I couldn't ask for Health access on this device. You can carry on, but your budgets will be based only on the figures you enter manually.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.red)
                Button("Continue anyway") { go(to: .bmr) }
            }
            Spacer()
        }
        .padding()
    }
    
    /// After logging, carry the just-entered weight into the BMR step and advance.
    private var logWeightCompletion: Binding<Bool> {
        Binding(get: { true }, set: { stillPresented in
            if !stillPresented {
                if todayLump.weightToday > 0 {
                    settingsObj.weight = Int(todayLump.weightToday.rounded())
                }
                go(to: .bmr)
            }
        })
    }

    private var logWeightScreen: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Log your weight").font(.title2).bold()
                Text("I couldn't find a recent weight in Apple Health, so pop your current weight in below. This sets your starting point and helps work out your budgets.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            // Inlined — LogWeightSheet writes to HealthKit and refreshes the lump,
            // then flips its binding, which advances us to the BMR step.
            LogWeightSheet(isDisplayed: logWeightCompletion)
                .environmentObject(todayLump)
                .scrollContentBackground(.hidden)
            
            Button("Skip for now") { go(to: .bmr) }
                .padding(.bottom)
        }
        // LogWeightSheet brings its own NavigationStack/title, like WeightGoalSheet.
        .toolbar(.hidden, for: .navigationBar)
    }

    private var bmrScreen: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Your height and weight").font(.title2).bold()
                Text("This helps calculate your budgets if there are gaps in your Health data, for instance if you didn't wear your Apple Watch one day.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            // Inlined — advances to .goal when its "Calculate" button flips the binding.
            BMRHelper(isPresented: completion(advancingTo: .goal),
                      manualBMR: $manualBMR,
                      manualActive: $manualActive)
            .scrollContentBackground(.hidden)
        }
    }

    private var goalScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Set your main goal").font(.title2).bold()
            Text("I want to...")
            Picker("Goal", selection: $chosenGoal) {
                Text("Lose weight").tag(1)
                Text("Stay the same").tag(2)
                Text("Gain weight").tag(3)
            }
            .pickerStyle(.segmented)
            Spacer()
            Button("Continue") {
                switch chosenGoal {
                case 1, 3:
                    go(to: .calorieTarget)
                case 2:
                    settingsObj.desiredDeficit = 0
                    go(to: .done)
                default:
                    break
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!goalChosen)
        }
        .padding()
        .onChange(of: chosenGoal, initial: false) { goalChosen = true }
    }

    private var calorieTargetScreen: some View {
        VStack(spacing: 16) {
            if chosenGoal == 1 {
                VStack(spacing: 8) {
                    Text("Set your calorie target").font(.title2).bold()
                    Text("This will help you calculate your calorie deficit each day, which will set your budget. You can change this later.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                // Inlined deficit chooser — advances to .goalWeight on selection.
                BudgetHelperView(isPresented: completion(advancingTo: .goalWeight),
                                 hideZero: true)
                .scrollContentBackground(.hidden)
            }

            if chosenGoal == 3 {
                Spacer()
                Text("Set your calorie target").font(.title2).bold()
                Text("Use the slider below to set your target caloric surplus.")
                    .multilineTextAlignment(.center)
                Slider(value: $desiredSurplus,
                       in: 50...1000,
                       step: 50,
                       minimumValueLabel: Text(""),
                       maximumValueLabel: Text(String(Int(desiredSurplus).formatted())),
                       label: { Text("Surplus") })
                .padding(.horizontal)
                Button("Save") {
                    settingsObj.surplusMode = true
                    settingsObj.desiredDeficit = Int(-desiredSurplus)
                    go(to: .goalWeight)
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
        }
    }

    private var goalWeightScreen: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Set your goal weight").font(.title2).bold()
                Text("This is where you can set your goal weight. You can change this later.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            // Inlined — advances to .done when "Add" flips the binding.
            WeightGoalSheet(isDisplayed: completion(advancingTo: .done))
                .environmentObject(todayLump)
                .scrollContentBackground(.hidden)
        }
        // WeightGoalSheet wraps itself in its own NavigationStack/title, so hide the
        // wizard's bar on this step to avoid a stacked double navigation bar.
        .toolbar(.hidden, for: .navigationBar)
    }

    private var doneScreen: some View {
        VStack(spacing: 20) {
            Spacer()
            Image("Happy bird")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .shadow(radius: 8)
            Text("You're all done! If you want to tweak anything, head to the Settings page by tapping the gear icon in the top left of the budget screen.")
                .multilineTextAlignment(.center)
            Text(.init(healthDisclaimer))
                .multilineTextAlignment(.center)
                .font(.callout)
            NavigationLink {
                Disclaimer(displayed: $disclaimerOn)
            } label: {
                Text("Read full health disclaimer")
            }
            Spacer()
            Button("Start using Budgie Diet") {
                settingsObj.isFirstRun = false
                Task { await dataStore.updateLump(todayLump: todayLump) }
                withAnimation(.easeInOut(duration: 0.5)) { needsSetup = false }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
