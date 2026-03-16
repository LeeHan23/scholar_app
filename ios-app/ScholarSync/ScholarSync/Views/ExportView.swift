import SwiftUI

struct ExportView: View {
    @Environment(\.dismiss) var dismiss
    let papers: [Paper]

    @State private var selectedFormat: ExportFormat = .bibtex
    @State private var showingShareSheet = false
    @State private var exportedFileURL: URL?
    @State private var showingZoteroSetup = false
    @State private var isExportingToZotero = false
    @State private var zoteroMessage: String?
    @State private var zoteroApiKey: String = ZoteroService.shared.apiKey ?? ""
    @State private var zoteroUserId: String = ZoteroService.shared.userId ?? ""

    enum ExportFormat: String, CaseIterable {
        case bibtex = "BibTeX (.bib)"
        case ris = "RIS (.ris)"
        case csv = "CSV (.csv)"
    }

    var body: some View {
        NavigationView {
            List {
                Section("File Export") {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }

                    Button(action: exportToFile) {
                        Label("Export \(papers.count) Papers", systemImage: "square.and.arrow.up")
                    }
                }

                Section {
                    if ZoteroService.shared.isConfigured {
                        Button(action: exportToZotero) {
                            HStack {
                                Label("Send to Zotero", systemImage: "arrow.up.forward.app")
                                Spacer()
                                if isExportingToZotero {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isExportingToZotero)

                        Button(role: .destructive) {
                            ZoteroService.shared.disconnect()
                            zoteroApiKey = ""
                            zoteroUserId = ""
                        } label: {
                            Label("Disconnect Zotero", systemImage: "xmark.circle")
                        }
                    } else {
                        Button(action: { showingZoteroSetup = true }) {
                            Label("Connect Zotero", systemImage: "link")
                        }
                    }
                } header: {
                    Text("Zotero")
                } footer: {
                    Text("Export directly to your Zotero library. Mendeley and EndNote can import BibTeX or RIS files.")
                }

                if let message = zoteroMessage {
                    Section {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(message.contains("Error") || message.contains("error") ? .red : .green)
                    }
                }

                Section {
                    Text("\(papers.count) papers will be exported")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Export Papers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportedFileURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Connect Zotero", isPresented: $showingZoteroSetup) {
                TextField("User ID", text: $zoteroUserId)
                TextField("API Key", text: $zoteroApiKey)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    ZoteroService.shared.userId = zoteroUserId.isEmpty ? nil : zoteroUserId
                    ZoteroService.shared.apiKey = zoteroApiKey.isEmpty ? nil : zoteroApiKey
                }
            } message: {
                Text("Find your User ID and API key at zotero.org/settings/keys")
            }
        }
    }

    private func exportToFile() {
        let citationFormat: CitationExporter.ExportFormat
        let fileExtension: String

        switch selectedFormat {
        case .bibtex:
            citationFormat = .bibtex
            fileExtension = "bib"
        case .ris:
            citationFormat = .ris
            fileExtension = "ris"
        case .csv:
            citationFormat = .csv
            fileExtension = "csv"
        }

        let content = CitationExporter.export(papers: papers, format: citationFormat)
        let filename = "ScholarSync_Export.\(fileExtension)"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            exportedFileURL = tempURL
            showingShareSheet = true
        } catch {
            zoteroMessage = "Error creating file: \(error.localizedDescription)"
        }
    }

    private func exportToZotero() {
        isExportingToZotero = true
        zoteroMessage = nil
        Task {
            do {
                let count = try await ZoteroService.shared.exportPapers(papers)
                zoteroMessage = "Successfully exported \(count) papers to Zotero."
            } catch {
                zoteroMessage = "Error: \(error.localizedDescription)"
            }
            isExportingToZotero = false
        }
    }
}

// MARK: - UIKit Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
