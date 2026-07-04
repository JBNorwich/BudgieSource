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
import CoreData
import Combine

enum MacSection: String, CaseIterable, Identifiable, Hashable {
    case today = "Today", food = "Food", water = "Water"
    var id: Self { self }
    var symbol: String {
        switch self {
        case .today: return "clock"
        case .food:  return "fork.knife"
        case .water: return "drop.fill"
        }
    }
}

struct MacRootView: View {
    @EnvironmentObject private var todayLump: TodayLump
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var nav = macNav
    @State private var needsPhoneSetup = settingsObj.isFirstRun
    @State private var showWhatsNew = false

    private var backgroundGradient: LinearGradient {
        LinearGradient(colors: colorScheme == .dark ? [.black, .blue] : [.cyan, .blue],
                       startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        Group {
            if needsPhoneSetup {
                ContentUnavailableView {
                    Label("Finish setup on your iPhone", systemImage: "iphone.gen3")
                } description: {
                    Text("Open Budgie Diet on your iPhone and complete the initial setup. Once it syncs to iCloud, your budget and logging will appear here.")
                }
                .frame(maxWidth: 460)
            } else {
                mainSplit
            }
        }
        .containerBackground(backgroundGradient, for: .window)
        .task { await refreshLoop() }
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).receive(on: RunLoop.main)) { _ in
            Task { @MainActor in await dataStore.updateLump(todayLump: todayLump) }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification).receive(on: RunLoop.main)) { _ in
            settingsObj.sync()
            needsPhoneSetup = settingsObj.isFirstRun
            Task { @MainActor in await dataStore.updateLump(todayLump: todayLump) }
        }
        .sheet(item: $nav.pendingAdd) { which in
            switch which {
            case .food:  MacAddFoodSheet(initialDate: Date()).environmentObject(todayLump)
            case .water: MacAddWaterSheet(dateToAddOn: Date()).environmentObject(todayLump)
            }
        }
        .onAppear {
            if shouldShowWhatsNew() { showWhatsNew = true }
        }
        .sheet(isPresented: $showWhatsNew,
               onDismiss: { settingsObj.lastOpenedVersion = whatsNewVersion }) {
            WhatsNewSheet(isDisplayed: $showWhatsNew)
        }
    }

    private var mainSplit: some View {
        NavigationSplitView {
            List(MacSection.allCases, selection: Binding($nav.section)) { section in
                Label(section.rawValue, systemImage: section.symbol).tag(section)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 200, max: 260)
            .navigationTitle("Budgie Diet")
        } detail: {
            switch nav.section {
            case .today: TodayPane()
            case .food:  MacFoodPane()
            case .water: MacWaterPane()
            }
        }
    }

    @MainActor
    private func refreshLoop() async {
        while !Task.isCancelled {
            settingsObj.sync()
            needsPhoneSetup = settingsObj.isFirstRun
            await dataStore.updateLump(todayLump: todayLump)
            try? await Task.sleep(for: .seconds(60))
        }
    }
}
