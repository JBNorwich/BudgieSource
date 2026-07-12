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
import UniformTypeIdentifiers

/// A JSON backup wrapped as a document so `.fileExporter` can save it wherever the user chooses.
struct JSONBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct DataManagementView: View {
    @EnvironmentObject var todayLump: TodayLump

    @State private var exportDocument: JSONBackupDocument?
    @State private var showingExporter = false
    @State private var isPreparing = false

    @State private var showingImporter = false
    @State private var pendingBackup: BudgieBackup?
    @State private var showingModeDialog = false
    @State private var showingReplaceConfirm = false

    @State private var resultMessage: String?
    @State private var showingResult = false

    private var defaultFilename: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return "BudgieDiet-Backup-\(df.string(from: Date()))"
    }

    var body: some View {
        Form {
            Section(footer: Text("Saves everything you've logged — your foods, calorie and water entries, meals and settings — to a single file. Keep it as a backup, or move it to another device. Your weight history isn't included; it stays in Apple Health.")) {
                Button {
                    Task { await prepareExport() }
                } label: {
                    if isPreparing {
                        ProgressView()
                    } else {
                        Text("Export all data…")
                    }
                }
                .disabled(isPreparing)
            }

            Section(footer: Text("Loads data from a file you exported before. “Merge” adds it to what's already here and won't remove anything. “Replace all” clears what's on this device first, then restores the file. Your settings are restored only when you choose Replace all.")) {
                Button("Import from a file…") { showingImporter = true }
            }
        }
        .navigationTitle("Backup and restore")
        .fileExporter(isPresented: $showingExporter,
                      document: exportDocument,
                      contentType: .json,
                      defaultFilename: defaultFilename) { result in
            if case .failure(let error) = result {
                present("Couldn't save the file. \(error.localizedDescription)")
            }
        }
        .fileImporter(isPresented: $showingImporter,
                      allowedContentTypes: [.json]) { result in
            handlePicked(result)
        }
        .confirmationDialog("How would you like to import this data?",
                            isPresented: $showingModeDialog, titleVisibility: .visible) {
            Button("Merge with my data") { runImport(.merge) }
            Button("Replace all my data…", role: .destructive) { showingReplaceConfirm = true }
            Button("Cancel", role: .cancel) { pendingBackup = nil }
        }
        .alert("Replace everything on this device?", isPresented: $showingReplaceConfirm) {
            Button("Replace all", role: .destructive) { runImport(.replace) }
            Button("Cancel", role: .cancel) { pendingBackup = nil }
        } message: {
            Text("This clears the foods, entries, meals and settings currently on this device, then restores them from the file. This can't be undone.")
        }
        .alert("Import & export", isPresented: $showingResult) {
            Button("OK") { }
        } message: {
            Text(resultMessage ?? "")
        }
    }

    @MainActor
    private func prepareExport() async {
        isPreparing = true
        let backup = await BackupService.makeBackup()
        do {
            let data = try BackupService.encode(backup)
            exportDocument = JSONBackupDocument(data: data)
            showingExporter = true
        } catch {
            present("Couldn't prepare the export. \(error.localizedDescription)")
        }
        isPreparing = false
    }

    private func handlePicked(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            present("Couldn't open that file. \(error.localizedDescription)")
        case .success(let url):
            let needsStop = url.startAccessingSecurityScopedResource()
            defer { if needsStop { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                pendingBackup = try BackupService.decode(data)
                showingModeDialog = true
            } catch {
                present("That doesn't look like a Budgie Diet backup, or it couldn't be read.")
            }
        }
    }

    private func runImport(_ mode: ImportMode) {
        guard let backup = pendingBackup else { return }
        pendingBackup = nil
        Task { @MainActor in
            await BackupService.restore(from: backup, mode: mode, todayLump: todayLump)
            present(mode == .merge ? "Your data has been merged in." : "Your data has been restored.")
        }
    }

    private func present(_ message: String) {
        resultMessage = message
        showingResult = true
    }
}
