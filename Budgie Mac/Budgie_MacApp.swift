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
import AppKit

// Mac counterparts of the iPhone globals in BudgieApp.swift.
// No `healthStore`/`localSettings`: the Mac has no HealthKit and never migrates legacy settings.
let settingsObj = CloudSettings()
let dataStore = HealthData.shared

@main
struct BudgieMacApp: App {          // ← keep whatever name Xcode gave this struct
    @StateObject private var todayLump = TodayLump()
    
    init() {
        // Pull the latest iCloud key-value settings (incl. the iPhone's budget snapshot) at launch.
        settingsObj.sync()
    }
    
    var body: some Scene {
        WindowGroup(id: "main") {
            MacRootView().environmentObject(todayLump).frame(minWidth: 760, minHeight: 500)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 900, height: 640)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Budgie Diet") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .applicationName: "Budgie Diet",
                        .credits: NSAttributedString(string: "The calorie budget app",
                            attributes: [.font: NSFont.systemFont(ofSize: 11), .link: URL(string: "https://joebaldwin.me.uk/apps/budgiediet")!])
                    ])
                }
            }
            
            CommandGroup(replacing: .newItem) {
                Button("Log Food…")  { macNav.pendingAdd = .food }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Log Water…") { macNav.pendingAdd = .water }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            CommandMenu("Go") {
                Button("Today") { macNav.section = .today }.keyboardShortcut("1", modifiers: .command)
                Button("Food")  { macNav.section = .food  }.keyboardShortcut("2", modifiers: .command)
                Button("Water") { macNav.section = .water }.keyboardShortcut("3", modifiers: .command)
            }
        }
        
        Settings {
            MacSettingsView()
        }
        
        MenuBarExtra {
            MenuBarView().environmentObject(todayLump)
        } label: {
            Image(systemName: "bird")             // ideally a monochrome template asset; SF Symbol is a fine start
        }
        .menuBarExtraStyle(.window)
    }
}
