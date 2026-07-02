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

import Foundation

/// Tracks distinct days of use and decides when to ask for an App Store review.
/// Uses standard UserDefaults deliberately: review eligibility is per-device, so we
/// don't want this synced across the user's devices via iCloud.
enum ReviewPrompt {
    private static let defaults = UserDefaults.standard
    private static let daysUsedKey = "reviewDistinctDaysUsed"
    private static let lastDayKey  = "reviewLastDayCounted"
    private static let askedKey    = "reviewHasBeenRequested"

    /// The number of distinct days before we ask.
    private static let threshold = 3

    /// Call once whenever the main screen becomes active. Returns true exactly when
    /// it's time to show the review prompt (threshold reached and never asked before).
    static func registerUseAndShouldPrompt() -> Bool {
        if defaults.bool(forKey: askedKey) { return false }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastCounted = defaults.object(forKey: lastDayKey) as? Date

        // Count today only if we haven't already counted a use for this calendar day.
        if lastCounted == nil || !calendar.isDate(lastCounted!, inSameDayAs: today) {
            defaults.set(defaults.integer(forKey: daysUsedKey) + 1, forKey: daysUsedKey)
            defaults.set(today, forKey: lastDayKey)
        }

        return defaults.integer(forKey: daysUsedKey) >= threshold
    }

    /// Record that we've made our one-and-only prompt attempt.
    static func markRequested() {
        defaults.set(true, forKey: askedKey)
    }
}
