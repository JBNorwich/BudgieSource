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
import UserNotifications

/// The app's *only* notification: a single, opt-in, local daily reminder to log food, fired at a
/// user-chosen time. Neutral and stateless by design — it never references the budget, progress, or
/// whether anything has been logged, and it is never scheduled unless the user has explicitly opted in
/// *on this device* (the preference lives in `UserSettings`, deliberately not synced via iCloud, so a
/// notification never fires on a device that hasn't been given permission). There are deliberately no
/// remote/push notifications anywhere in Budgie Diet.
enum FoodReminder {
    /// Single reusable request identifier — rescheduling always replaces this one pending request.
    private static let identifier = "foodLoggingReminder"

    private static var centre: UNUserNotificationCenter { .current() }

    /// Ask for notification permission the first time the user opts in. Returns whether we may post.
    /// `.notDetermined` triggers the system prompt; an existing `.denied` can't be re-prompted, so we
    /// report failure and let the caller send the user to the Settings app.
    static func requestAuthorisation() async -> Bool {
        switch await centre.notificationSettings().authorizationStatus {
        case .notDetermined:
            return (try? await centre.requestAuthorization(options: [.alert, .sound])) ?? false
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    /// Bring the scheduled reminder into line with the given preference and the current permission
    /// state. Callers read the device-local preference (from `UserSettings`) and pass it in, keeping
    /// this type free of any app-specific storage dependency so it compiles cleanly in every target.
    /// Safe to call anytime (launch, toggle change, time change) — it always clears the old request
    /// first, then re-adds one only if `enabled` and we're allowed to post.
    static func reschedule(enabled: Bool, minutesIntoDay: Int) async {
        centre.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard enabled else { return }
        switch await centre.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: break
        default: return
        }

        let content = UNMutableNotificationContent()
        content.body = "Here's your reminder to log food for the day."
        content.sound = .default

        var when = DateComponents()
        when.hour = minutesIntoDay / 60
        when.minute = minutesIntoDay % 60
        // Repeating on hour+minute only => fires daily at that local wall-clock time, following the
        // device's own timezone. Unconditional: we never suppress based on what's been logged.
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)

        try? await centre.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }
}
