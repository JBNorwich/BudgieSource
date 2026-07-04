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
import Combine

enum QuickAdd: Identifiable { case food, water; var id: Int { self == .food ? 0 : 1 } }

final class MacNavigation: ObservableObject {
    @Published var section: MacSection { didSet {
        UserDefaults.standard.set(section.rawValue, forKey: "macSelectedSection")
    } }
    /// One-shot request to present a logging sheet; MacRootView consumes it.
    @Published var pendingAdd: QuickAdd?

    init() {
        let saved = UserDefaults.standard.string(forKey: "macSelectedSection")
        section = saved.flatMap(MacSection.init(rawValue:)) ?? .today
    }
}

let macNav = MacNavigation()   // a global, matching settingsObj / dataStore
