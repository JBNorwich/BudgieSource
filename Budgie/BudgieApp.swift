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

let healthStore: HKHealthStore = HKHealthStore()
let settingsObj: CloudSettings = CloudSettings()
let localSettings: UserSettings = UserSettings()
let dataStore: HealthData = HealthData.shared

@main
struct BudgieApp: App {
    init() {
        settingsObj.sync()
        Task {
            if await dataStore.calorieActor.getListOfMeals() == [] {
                await dataStore.calorieActor.setUpMeals()
            }
            if settingsObj.snacksUUID == nil {
                settingsObj.snacksUUID = await dataStore.calorieActor.getMealUUIDbyName(name: "Snacks/Other")
            }
        }
        // `localSettings.onCloud` is a permanent, device-local latch. Once it is true, the
        // one-time local→cloud migration can NEVER run again on this device — local settings
        // must never overwrite cloud settings after the initial migration, even if the
        // iCloud key-value store is later unavailable or comes back empty.
        if settingsObj.onCloud {
            // Cloud settings are live; make sure this device is latched.
            if localSettings.onCloud == false {
                localSettings.onCloud = true
            }
        } else if localSettings.onCloud == false {
            if localSettings.isFirstRun == false {
                // Legacy local settings exist and have never been copied up: migrate once.
                // copyFromLocal() sets both latches when it finishes.
                settingsObj.copyFromLocal(localObj: localSettings)
            } else {
                // Nothing to migrate on this device.
                localSettings.onCloud = true
                settingsObj.onCloud = true
            }
        }
    }

    var body: some Scene {
           WindowGroup {
               RootView()
           }
       }
   }

   /// Chooses between first-run setup and the main app, crossfading between them
   /// when setup completes. `CloudSettings` isn't observable, so we mirror its
   /// first-run flag into local state that the wizard flips when it's done.
struct RootView: View {
    @State private var needsSetup = settingsObj.isFirstRun
    
    var body: some View {
        ZStack {
            if needsSetup {
                FirstRunWizard(needsSetup: $needsSetup)
                    .transition(.opacity)
            } else {
                BudgetView()
                    .transition(.opacity)
            }
        }
    }
}
