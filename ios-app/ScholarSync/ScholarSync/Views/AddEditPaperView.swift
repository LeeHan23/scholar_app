import SwiftUI
import CoreLocation
import UniformTypeIdentifiers

struct AddEditPaperView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var locationManager = LocationManager.shared

    let paper: Paper?
    let projects: [Project]
    let onSave: (Paper) -> Void
    let onPDFSelected: ((Data) -> Void)?

    @State private var title: String
    @State private var authors: String
    @State private var journal: String
    @State private var year: String
    @State private var doi: String
    @State private var abstract: String
    @State private var selectedProjectId: Int?
    @State private var pageNumber: String
    @State private var locationName: String
    @State private var tagsText: String
    @State private var newTag: String = ""
    @State private var tagsList: [String]

    // PDF extraction
    @State private var showingPDFPicker = false
    @State private var isExtracting = false
    @State private var extractionStatus: String?
    @State private var pdfData: Data?
    @State private var pdfFileName: String?

    init(paper: Paper? = nil, projects: [Project], onSave: @escaping (Paper) -> Void, onPDFSelected: ((Data) -> Void)? = nil) {
        self.paper = paper
        self.projects = projects
        self.onSave = onSave
        self.onPDFSelected = onPDFSelected
        _title = State(initialValue: paper?.title ?? "")
        _authors = State(initialValue: paper?.authors ?? "")
        _journal = State(initialValue: paper?.journal ?? "")
        _year = State(initialValue: paper != nil ? String(paper!.year) : String(Calendar.current.component(.year, from: Date())))
        _doi = State(initialValue: paper?.doi ?? "")
        _abstract = State(initialValue: paper?.abstract ?? "")
        _selectedProjectId = State(initialValue: paper?.projectId)
        _pageNumber = State(initialValue: paper?.pageNumber ?? "")
        _locationName = State(initialValue: paper?.locationName ?? "")
        _tagsText = State(initialValue: paper?.tags ?? "")
        _tagsList = State(initialValue: paper?.tagsList ?? [])
    }

    var body: some View {
        NavigationView {
            Form {
                // PDF Upload section — shown at top to encourage upload-first flow
                Section {
                    if isExtracting {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Extracting metadata...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else if let fileName = pdfFileName {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.fill")
                                .font(.title3)
                                .foregroundColor(.red)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(fileName)
                                    .font(.subheadline.bold())
                                    .lineLimit(1)
                                if let status = extractionStatus {
                                    Text(status)
                                        .font(.caption)
                                        .foregroundColor(status.contains("CrossRef") ? .green : .orange)
                                }
                            }
                            Spacer()
                            Button("Change") {
                                showingPDFPicker = true
                            }
                            .font(.subheadline)
                        }
                    } else {
                        Button {
                            showingPDFPicker = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.badge.plus")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Upload PDF")
                                        .font(.subheadline.bold())
                                    Text("Auto-fills title, authors, and more")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("PDF")
                } footer: {
                    if pdfFileName == nil {
                        Text("Select a PDF to automatically extract paper details.")
                    }
                }

                Section("Paper Details") {
                    TextField("Title *", text: $title)
                    TextField("Authors *", text: $authors)
                    TextField("Journal / Conference", text: $journal)
                    TextField("Year", text: $year)
                        .keyboardType(.numberPad)
                    TextField("DOI", text: $doi)
                        .autocapitalization(.none)
                }

                Section("Abstract") {
                    TextEditor(text: $abstract)
                        .frame(minHeight: 100)
                }

                Section("Page Reference") {
                    TextField("Page number (e.g. 42 or 42-45)", text: $pageNumber)
                        .keyboardType(.numbersAndPunctuation)
                }

                Section {
                    HStack {
                        TextField("Location", text: $locationName)
                        Button(action: fetchCurrentLocation) {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                        }
                    }
                } header: {
                    Text("Location")
                } footer: {
                    Text("Tap the location icon to tag with your current location.")
                }

                Section {
                    FlowTagsView(tags: $tagsList)

                    HStack {
                        TextField("Add tag", text: $newTag)
                            .autocapitalization(.none)
                        Button(action: addTag) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Tags")
                }

                if !projects.isEmpty {
                    Section("Project") {
                        Picker("Assign to Project", selection: $selectedProjectId) {
                            Text("None").tag(nil as Int?)
                            ForEach(projects) { project in
                                Text(project.name).tag(project.id as Int?)
                            }
                        }
                    }
                }
            }
            .navigationTitle(paper == nil ? "Add Paper" : "Edit Paper")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { savePaper() }
                        .disabled(title.isEmpty || authors.isEmpty)
                        .bold()
                }
            }
            .sheet(isPresented: $showingPDFPicker) {
                PDFDocumentPicker { data, fileName in
                    pdfData = data
                    pdfFileName = fileName
                    extractMetadata(from: data)
                }
            }
        }
    }

    // MARK: - PDF Extraction

    private func extractMetadata(from data: Data) {
        isExtracting = true
        extractionStatus = nil

        Task {
            let metadata = await PDFExtractor.shared.extract(from: data)

            await MainActor.run {
                // Only fill empty fields
                if let t = metadata.title, title.isEmpty {
                    title = t
                }
                if let a = metadata.authors, authors.isEmpty {
                    authors = a
                }
                if let j = metadata.journal, journal.isEmpty {
                    journal = j
                }
                if let y = metadata.year, year == String(Calendar.current.component(.year, from: Date())) {
                    year = String(y)
                }
                if let d = metadata.doi, doi.isEmpty {
                    doi = d
                }
                if let a = metadata.abstract, abstract.isEmpty {
                    abstract = a
                }

                switch metadata.source {
                case "crossref":
                    extractionStatus = "Auto-filled from CrossRef"
                case "pdf":
                    extractionStatus = "Extracted from PDF — please verify"
                default:
                    extractionStatus = "Could not extract — fill in manually"
                }

                isExtracting = false
            }
        }
    }

    // MARK: - Actions

    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty,
              tag.count <= 50,
              tagsList.count < 20,
              !tagsList.contains(tag) else { return }
        tagsList.append(tag)
        newTag = ""
    }

    private func fetchCurrentLocation() {
        locationManager.requestLocation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if let name = locationManager.currentPlaceName {
                locationName = name
            }
        }
    }

    private func savePaper() {
        let yearInt = Int(year) ?? Calendar.current.component(.year, from: Date())
        let location = locationManager.currentLocation

        var savedPaper = Paper(
            id: paper?.id,
            title: title,
            authors: authors,
            journal: journal.isEmpty ? nil : journal,
            year: yearInt,
            doi: doi.isEmpty ? nil : doi,
            abstract: abstract.isEmpty ? nil : abstract,
            status: paper?.status ?? .unread,
            userId: paper?.userId,
            projectId: selectedProjectId,
            locationName: locationName.isEmpty ? nil : locationName,
            latitude: paper?.latitude,
            longitude: paper?.longitude,
            pageNumber: pageNumber.isEmpty ? nil : pageNumber
        )

        savedPaper.setTags(tagsList)

        if !locationName.isEmpty && locationName != paper?.locationName {
            savedPaper.latitude = location?.coordinate.latitude
            savedPaper.longitude = location?.coordinate.longitude
        }

        onSave(savedPaper)

        // Upload PDF if selected
        if let data = pdfData {
            onPDFSelected?(data)
        }

        dismiss()
    }
}

// MARK: - PDF Document Picker

struct PDFDocumentPicker: UIViewControllerRepresentable {
    let onPick: (Data, String) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (Data, String) -> Void

        init(onPick: @escaping (Data, String) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            if let data = try? Data(contentsOf: url) {
                onPick(data, url.lastPathComponent)
            }
        }
    }
}

// MARK: - Tags Display

struct FlowTagsView: View {
    @Binding var tags: [String]

    var body: some View {
        if !tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag)
                                .font(.caption)
                            Button(action: { tags.removeAll { $0 == tag } }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption2)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
}
