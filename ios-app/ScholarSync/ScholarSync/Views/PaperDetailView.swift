import SwiftUI
import UniformTypeIdentifiers
import WebKit

struct PaperDetailView: View {
    @EnvironmentObject var viewModel: QueueViewModel
    @Environment(\.dismiss) var dismiss

    let paper: Paper
    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false
    @State private var showingMoveToProject = false
    @State private var showingPDFPicker = false
    @State private var isUploadingPDF = false
    @State private var pdfSignedURL: URL?

    private var currentProject: Project? {
        guard let pid = paper.projectId else { return nil }
        return viewModel.projects.first { $0.id == pid }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Title & status
                HStack(alignment: .top) {
                    Text(paper.title)
                        .font(.title2.bold())
                    Spacer()
                    Text(paper.status == .unread ? "Unread" : "Read")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(paper.status == .unread ? Color.blue.opacity(0.15) : Color.green.opacity(0.15))
                        .foregroundColor(paper.status == .unread ? .blue : .green)
                        .cornerRadius(8)
                }

                // Authors
                Text(paper.authors)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // Metadata row
                HStack(spacing: 16) {
                    if let journal = paper.journal, !journal.isEmpty {
                        Label(journal, systemImage: "book")
                            .font(.caption)
                    }
                    Label(String(paper.year), systemImage: "calendar")
                        .font(.caption)
                    if let page = paper.pageNumber {
                        Label("p. \(page)", systemImage: "doc.text")
                            .font(.caption)
                    }
                }
                .foregroundColor(.secondary)

                // DOI
                if let doi = paper.doi, !doi.isEmpty {
                    HStack {
                        Text("DOI:")
                            .font(.caption.bold())
                        Text(doi)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }

                // Project
                if let project = currentProject {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.blue)
                        Text(project.name)
                            .font(.subheadline)
                    }
                }

                // Location
                if let location = paper.locationName, !location.isEmpty {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.red)
                        Text(location)
                            .font(.subheadline)
                    }
                }

                // Tags
                if !paper.tagsList.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(paper.tagsList, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.gray.opacity(0.12))
                                    .cornerRadius(12)
                            }
                        }
                    }
                }

                // Abstract
                if let abstract = paper.abstract, !abstract.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Abstract")
                            .font(.headline)
                        Text(abstract)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }

                // PDF section
                VStack(alignment: .leading, spacing: 10) {
                    Text("PDF")
                        .font(.headline)

                    if paper.pdfUrl != nil {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                            VStack(alignment: .leading) {
                                Text("PDF Attached")
                                    .font(.subheadline.bold())
                                Text("Tap View to open")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button {
                                Task { await openPDF() }
                            } label: {
                                Label("View", systemImage: "eye")
                                    .font(.subheadline.bold())
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                    }

                    Button {
                        showingPDFPicker = true
                    } label: {
                        Label(
                            isUploadingPDF ? "Uploading..." : (paper.pdfUrl != nil ? "Replace PDF" : "Attach PDF"),
                            systemImage: paper.pdfUrl != nil ? "arrow.triangle.2.circlepath" : "paperclip"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.indigo)
                    .disabled(isUploadingPDF)
                }

                Divider()

                // Action buttons
                VStack(spacing: 12) {
                    // Toggle read/unread
                    Button {
                        Task {
                            await viewModel.togglePaperStatus(paper)
                            dismiss()
                        }
                    } label: {
                        Label(
                            paper.status == .unread ? "Mark as Read" : "Mark as Unread",
                            systemImage: paper.status == .unread ? "checkmark.circle" : "circle"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)

                    // Edit
                    Button {
                        showingEdit = true
                    } label: {
                        Label("Edit Paper", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)

                    // Move to project
                    Button {
                        showingMoveToProject = true
                    } label: {
                        Label(
                            paper.projectId != nil ? "Move to Another Project" : "Add to Project",
                            systemImage: "folder.badge.plus"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)

                    // Delete
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Delete Paper", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
            .padding()
        }
        .navigationTitle("Paper Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEdit) {
            AddEditPaperView(paper: paper, projects: viewModel.projects) { updatedPaper in
                Task {
                    await viewModel.updatePaper(updatedPaper)
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingMoveToProject) {
            MoveToProjectSheet(paper: paper)
        }
        .alert("Delete Paper?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deletePaper(paper)
                    dismiss()
                }
            }
        } message: {
            Text("This will permanently remove \"\(paper.title)\" from your library.")
        }
        .sheet(isPresented: $showingPDFPicker) {
            DocumentPicker { data in
                isUploadingPDF = true
                Task {
                    await viewModel.uploadPDF(for: paper, data: data)
                    isUploadingPDF = false
                }
            }
        }
        .sheet(item: $pdfSignedURL) { url in
            PDFWebView(url: url)
        }
    }

    private func openPDF() async {
        guard let path = paper.pdfUrl else { return }
        do {
            let url = try await SupabaseManager.shared.getSignedPDFUrl(path: path)
            pdfSignedURL = url
        } catch {
            viewModel.errorMessage = "Failed to load PDF: \(error.localizedDescription)"
        }
    }
}

// Make URL identifiable for .sheet(item:)
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (Data) -> Void

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
        let onPick: (Data) -> Void

        init(onPick: @escaping (Data) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            if let data = try? Data(contentsOf: url) {
                onPick(data)
            }
        }
    }
}

// MARK: - PDF Viewer

struct PDFWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// MARK: - Move to Project Sheet

struct MoveToProjectSheet: View {
    @EnvironmentObject var viewModel: QueueViewModel
    @Environment(\.dismiss) var dismiss
    let paper: Paper

    var body: some View {
        NavigationView {
            List {
                // Remove from project option
                if paper.projectId != nil {
                    Button {
                        moveTo(projectId: nil)
                    } label: {
                        Label("Remove from Project", systemImage: "folder.badge.minus")
                            .foregroundColor(.red)
                    }
                }

                Section("Projects") {
                    if viewModel.projects.isEmpty {
                        Text("No projects yet. Create one in the Projects tab.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.projects) { project in
                            Button {
                                moveTo(projectId: project.id)
                            } label: {
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(.blue)
                                    Text(project.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if paper.projectId == project.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Move to Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func moveTo(projectId: Int?) {
        var updated = paper
        updated.projectId = projectId
        Task {
            await viewModel.updatePaper(updated)
            dismiss()
        }
    }
}
