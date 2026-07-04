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

struct MenuBarView: View {
    @EnvironmentObject private var todayLump: TodayLump
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Passive glance — no colour states, no "you should…" language.
            if settingsObj.snapshotTimestamp == 0 {
                Text("Waiting for your iPhone to sync.").foregroundStyle(.secondary)
            } else if settingsObj.budgetSnapshotIsFresh {
                glance(number: todayLump.canEatNow, caption: "left to eat now")   // ← the live figure MeterView shows
            } else {
                glance(number: todayLump.totalBudget, caption: "today's budget · not live")
            }

            HStack(spacing: 6) {
                Image(systemName: "drop.fill").foregroundStyle(.blue)
                Text("\(renderVolume(millilitres: todayLump.waterToday)) of \(renderVolume(millilitres: todayLump.effectiveWaterGoal))")
                    .foregroundStyle(.secondary)
            }.font(.callout)

            Divider()
            Button("Log food…")  { present(.food) }
            Button("Log water…") { present(.water) }
            Button("Open Budgie Diet") { open() }
            Divider()
            Button("Quit Budgie Diet") { NSApp.terminate(nil) }
        }
        .buttonStyle(.plain)
        .frame(width: 240)
        .padding(12)
    }

    private func glance(number: Int, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(number.formatted()) kcal")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .contentTransition(.numericText())
            Text(caption).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func open() { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
    private func present(_ add: QuickAdd) { open(); macNav.pendingAdd = add }
}
