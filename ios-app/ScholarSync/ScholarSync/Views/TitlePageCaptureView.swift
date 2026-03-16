import SwiftUI

struct TitlePageCaptureView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: QueueViewModel

    @State private var showingImagePicker = false
    @State private var imageSource: UIImagePickerController.SourceType = .camera
    @State private var capturedImage: UIImage?
    @State private var isProcessing = false
    @State private var extractedInfo: TitlePageReader.ExtractedInfo?
    @State private var errorMessage: String?

    // Editable extracted fields
    @State private var title = ""
    @State private var authors = ""
    @State private var publisher = ""
    @State private var year = ""

    let projects: [Project]

    var body: some View {
        NavigationView {
            Group {
                if let _ = extractedInfo {
                    reviewForm
                } else {
                    capturePrompt
                }
            }
            .navigationTitle("Title Page Reader")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $capturedImage, sourceType: imageSource)
            }
            .onChange(of: capturedImage) { newImage in
                if let image = newImage {
                    processImage(image)
                }
            }
        }
    }

    // MARK: - Capture Prompt

    private var capturePrompt: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "doc.viewfinder")
                .font(.system(size: 64))
                .foregroundColor(.blue)

            Text("Capture a Title Page")
                .font(.title2)
                .bold()

            Text("Take a photo of a book's title page or copyright page to automatically extract citation information.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if isProcessing {
                ProgressView("Extracting text...")
                    .padding()
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }

            VStack(spacing: 12) {
                Button(action: {
                    imageSource = .camera
                    showingImagePicker = true
                }) {
                    Label("Take Photo", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)

                Button(action: {
                    imageSource = .photoLibrary
                    showingImagePicker = true
                }) {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Review Form

    private var reviewForm: some View {
        Form {
            if let image = capturedImage {
                Section {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(8)
                }
            }

            Section("Extracted Information") {
                TextField("Title", text: $title)
                TextField("Authors", text: $authors)
                TextField("Publisher / Journal", text: $publisher)
                TextField("Year", text: $year)
                    .keyboardType(.numberPad)
            }

            Section {
                Button(action: saveExtracted) {
                    Label("Save to Queue", systemImage: "plus.circle.fill")
                }
                .disabled(title.isEmpty)

                Button(action: retake) {
                    Label("Retake Photo", systemImage: "arrow.counterclockwise")
                }
            }
        }
    }

    // MARK: - Actions

    private func processImage(_ image: UIImage) {
        isProcessing = true
        errorMessage = nil

        Task {
            do {
                let info = try await TitlePageReader.extractInfo(from: image)
                extractedInfo = info
                title = info.title ?? ""
                authors = info.authors ?? ""
                publisher = info.publisher ?? ""
                year = info.year != nil ? String(info.year!) : ""
            } catch {
                errorMessage = "Could not extract text: \(error.localizedDescription)"
            }
            isProcessing = false
        }
    }

    private func saveExtracted() {
        let yearInt = Int(year) ?? Calendar.current.component(.year, from: Date())

        // If an ISBN was extracted, try looking it up for richer metadata
        if let isbn = extractedInfo?.isbn, !isbn.isEmpty {
            Task {
                do {
                    let fetched = try await CrossrefService.shared.fetchPaper(doi: isbn)
                    await viewModel.addPaper(fetched)
                } catch {
                    // Fallback to manually entered fields
                    let paper = Paper(
                        title: title,
                        authors: authors,
                        journal: publisher.isEmpty ? nil : publisher,
                        year: yearInt,
                        status: .unread
                    )
                    await viewModel.addPaper(paper)
                }
                dismiss()
            }
        } else {
            let paper = Paper(
                title: title,
                authors: authors,
                journal: publisher.isEmpty ? nil : publisher,
                year: yearInt,
                status: .unread
            )
            Task {
                await viewModel.addPaper(paper)
                dismiss()
            }
        }
    }

    private func retake() {
        capturedImage = nil
        extractedInfo = nil
        title = ""
        authors = ""
        publisher = ""
        year = ""
        errorMessage = nil
    }
}

// MARK: - UIKit Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
