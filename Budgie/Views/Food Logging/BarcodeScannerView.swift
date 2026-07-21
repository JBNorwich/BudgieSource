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
import VisionKit

/// Live camera view that recognises a food barcode and hands back the first result. Stops itself after one read.
struct BarcodeScannerView: UIViewControllerRepresentable {
    var onScan: (String) -> Void
    /// Called if the camera fails to start (e.g. permission denied/revoked), so the caller can fall
    /// back to manual entry instead of leaving a dead, unresponsive camera view on screen.
    var onFailure: () -> Void = {}

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce])],
            qualityLevel: .balanced,
            isHighFrameRateTrackingEnabled: false,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        do {
            try vc.startScanning()
        } catch {
            DispatchQueue.main.async { onFailure() }
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        private var hasScanned = false
        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !hasScanned, case let .barcode(barcode) = addedItems.first, let payload = barcode.payloadStringValue else { return }
            hasScanned = true
            dataScanner.stopScanning()
            onScan(payload)
        }
    }
}

struct BarcodeScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var manualBarcode = ""
    @State private var scanFailed = false
    /// Async so the sheet can wait for it (e.g. a local-library lookup) before dismissing — dismissing
    /// first and letting the caller's follow-up state change land later would race presenting whatever
    /// sheet comes next (SwiftUI doesn't reliably present a new sheet while this one is still dismissing).
    var onScan: (String) async -> Void

    private var trimmedBarcode: String { manualBarcode.filter(\.isNumber) }
    private var cameraUnavailable: Bool { !DataScannerViewController.isSupported || !DataScannerViewController.isAvailable }

    private func handleScan(_ code: String) {
        Task {
            await onScan(code)
            dismiss()
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if cameraUnavailable || scanFailed {
                    manualEntryView
                } else {
                    BarcodeScannerView(onScan: handleScan, onFailure: { scanFailed = true })
                        .ignoresSafeArea()
                }
            }
            .navigationTitle("Scan barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var manualEntryView: some View {
        Form {
            Section {
                TextField("Barcode number", text: $manualBarcode)
                    .keyboardType(.numberPad)
            } footer: {
                Text(cameraUnavailable
                    ? "Camera scanning isn't available on this device. Type the number printed under the barcode instead."
                    : "The camera couldn't be started — check that Budgie Diet has camera access in Settings, or type the number printed under the barcode instead.")
            }
            Button("Look up") { handleScan(trimmedBarcode) }
                .disabled(trimmedBarcode.isEmpty)
        }
    }
}

/// Adds a "Scan barcode" toolbar button (hidden when the user has disabled OpenFoodFacts search) and
/// the scan → OpenFoodFacts-lookup sheet flow, handing back the picked product via `onPick`. Shared by
/// every screen that lets the user add a food by barcode (AddCalsSheet, the meal-ingredient picker),
/// so a future fix to the scan flow only needs to be made once.
private struct BarcodeScanning: ViewModifier {
    let onPick: (PickedFood) -> Void

    @State private var showingScanner = false
    @State private var scannedBarcode: ScannedBarcode?

    private struct ScannedBarcode: Identifiable {
        let id: String
        var barcode: String { id }
    }

    func body(content: Content) -> some View {
        content
            .toolbar {
                if !settingsObj.offSearchDisabled {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingScanner = true
                        } label: {
                            Label("Scan barcode", systemImage: "barcode.viewfinder")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingScanner) {
                BarcodeScannerSheet { code in
                    // A barcode already saved locally (from an earlier OFF import, or created
                    // manually because OFF didn't have it) resolves instantly, without a network
                    // round-trip that would just end in the same "not found" result again. Awaited
                    // by the sheet itself before it dismisses, so this state change always lands
                    // before (never racing) the sheet presented next.
                    if let existing = await dataStore.foodItemActor.fetch(barcode: code) {
                        onPick(existing.asPicked)
                    } else {
                        scannedBarcode = ScannedBarcode(id: code)
                    }
                }
            }
            .sheet(item: $scannedBarcode) { scanned in
                OpenFoodFactsSheet(barcode: scanned.barcode) { food in
                    scannedBarcode = nil
                    onPick(food)
                }
            }
    }
}

extension View {
    /// See `BarcodeScanning`.
    func barcodeScanning(onPick: @escaping (PickedFood) -> Void) -> some View {
        modifier(BarcodeScanning(onPick: onPick))
    }
}
