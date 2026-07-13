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
import CoreData
import Combine

/// Observes NSPersistentCloudKitContainer's own sync events so the UI can show an honest "Syncing from iCloud…" state on a fresh install, rather than a blank list that reads as data loss. Strictly read-only: it never triggers, forces or alters syncing — CloudKit can't be forced — it only reports what CloudKit is already doing.
final class CloudSyncMonitor: ObservableObject {
    static let shared = CloudSyncMonitor()

    /// True whenever at least one CloudKit import is currently in flight. While this is true and a list is empty, the freshest records may simply not have arrived yet.
    @Published private(set) var isImporting = false

    private var inFlight = Set<UUID>()   // keyed by event id, so both stores are tracked together

    private init() {
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            self?.handle(note)
        }
    }

    private func handle(_ note: Notification) {
        guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event,
              event.type == .import else { return }

        if event.endDate == nil {
            inFlight.insert(event.identifier)      // an import batch has just started
        } else {
            inFlight.remove(event.identifier)      // …and this one has finished
        }
        isImporting = !inFlight.isEmpty
    }
}
