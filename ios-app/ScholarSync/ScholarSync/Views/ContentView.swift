import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: QueueViewModel
    @EnvironmentObject var storeManager: StoreManager
    @Binding var isLoggedIn: Bool

    var body: some View {
        TabView {
            ReadingQueueView(isLoggedIn: $isLoggedIn)
                .tabItem {
                    Label("Queue", systemImage: "book")
                }

            ProjectsView()
                .tabItem {
                    Label("Projects", systemImage: "folder")
                }
                .badge(viewModel.pendingInvitations.count > 0 ? viewModel.pendingInvitations.count : 0)
        }
        .task {
            await viewModel.loadData()
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

// MARK: - Reading Queue

struct ReadingQueueView: View {
    @EnvironmentObject var viewModel: QueueViewModel
    @EnvironmentObject var storeManager: StoreManager
    @Binding var isLoggedIn: Bool
    @State private var showingAddPaper = false
    @State private var showingScanner = false
    @State private var showingTitlePageCapture = false
    @State private var showingExport = false
    @State private var editingPaper: Paper?
    @AppStorage("hasSeenSwipeHint") private var hasSeenSwipeHint = false

    // Post-scan page number flow
    @State private var pendingScannedCode: String?
    @State private var scanPageNumber = ""
    @State private var showingPageNumberPrompt = false

    var body: some View {
        NavigationView {
            List {
                // Gesture guide — shows once until dismissed
                if !hasSeenSwipeHint && !viewModel.papers.isEmpty {
                    GestureHintCard {
                        withAnimation { hasSeenSwipeHint = true }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                if viewModel.papers.isEmpty && !viewModel.isLoading {
                    VStack(alignment: .center, spacing: 16) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No papers yet")
                            .font(.headline)
                        Text("Tap + to add a paper manually, scan a DOI, or capture a title page.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.papers) { paper in
                        NavigationLink(destination: PaperDetailView(paper: paper)) {
                            PaperRow(paper: paper)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await viewModel.deletePaper(paper) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                editingPaper = paper
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                Task { await viewModel.togglePaperStatus(paper) }
                            } label: {
                                Label(
                                    paper.status == .unread ? "Read" : "Unread",
                                    systemImage: paper.status == .unread ? "checkmark.circle" : "circle"
                                )
                            }
                            .tint(.green)
                        }
                    }
                }
            }
            .navigationTitle("Reading Queue")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Export
                    Button(action: { showingExport = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(viewModel.papers.isEmpty)

                    // Add menu: manual, scan DOI, capture title page
                    Menu {
                        Button(action: { showingAddPaper = true }) {
                            Label("Add Manually", systemImage: "plus")
                        }
                        Button(action: {
                            if storeManager.canCapture() {
                                showingScanner = true
                            }
                        }) {
                            Label("Scan DOI / ISBN", systemImage: "qrcode.viewfinder")
                        }
                        Button(action: { showingTitlePageCapture = true }) {
                            Label("Capture Title Page", systemImage: "camera")
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        SupabaseManager.shared.signOut()
                        isLoggedIn = false
                    }) {
                        Text("Logout")
                            .font(.subheadline)
                    }
                }
            }
            .refreshable {
                await viewModel.loadData()
            }
            .sheet(isPresented: $showingAddPaper) {
                AddEditPaperView(projects: viewModel.projects) { paper in
                    Task {
                        await viewModel.addPaper(paper)
                    }
                } onPDFSelected: { data in
                    // Upload PDF after the paper is saved — uses the latest paper in the list
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000) // wait for paper to save
                        if let saved = viewModel.papers.first {
                            await viewModel.uploadPDF(for: saved, data: data)
                        }
                    }
                }
            }
            .sheet(item: $editingPaper) { paper in
                AddEditPaperView(paper: paper, projects: viewModel.projects) { updatedPaper in
                    Task { await viewModel.updatePaper(updatedPaper) }
                } onPDFSelected: { data in
                    Task { await viewModel.uploadPDF(for: paper, data: data) }
                }
            }
            .sheet(isPresented: $showingScanner) {
                ScannerViewWrapper(isPresented: $showingScanner) { code in
                    pendingScannedCode = code
                    scanPageNumber = ""
                    showingPageNumberPrompt = true
                }
            }
            .sheet(isPresented: $showingTitlePageCapture) {
                TitlePageCaptureView(projects: viewModel.projects)
            }
            .sheet(isPresented: $showingExport) {
                ExportView(papers: viewModel.papers)
            }
            .alert("Add Page Number?", isPresented: $showingPageNumberPrompt) {
                TextField("Page number (optional)", text: $scanPageNumber)
                    .keyboardType(.numbersAndPunctuation)
                Button("Skip") { finalizeScannedPaper(pageNumber: nil) }
                Button("Save") { finalizeScannedPaper(pageNumber: scanPageNumber) }
            } message: {
                Text("Optionally tag the page number for this scan.")
            }
        }
    }

    private func finalizeScannedPaper(pageNumber: String?) {
        guard let code = pendingScannedCode else { return }
        let page = pageNumber?.isEmpty == true ? nil : pageNumber
        StoreManager.shared.incrementCapture()
        Task {
            await viewModel.handleScannedCode(code, pageNumber: page)
        }
        pendingScannedCode = nil
    }
}

// MARK: - Scanner Wrapper

struct ScannerViewWrapper: View {
    @Binding var isPresented: Bool
    @State private var localScannedCode: String?
    let onScanned: (String) -> Void

    var body: some View {
        NavigationView {
            ScannerView(scannedCode: $localScannedCode)
                .navigationTitle("Scan Paper ID")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            isPresented = false
                        }
                    }
                }
                .onChange(of: localScannedCode) { newValue in
                    if let code = newValue {
                        isPresented = false
                        onScanned(code)
                    }
                }
        }
    }
}

// MARK: - Gesture Hint Card

struct GestureHintCard: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Quick Actions")
                    .font(.subheadline.bold())
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 0) {
                gestureItem(
                    icon: "hand.tap",
                    label: "Tap",
                    detail: "View details",
                    color: .blue
                )
                Divider().frame(height: 40)
                gestureItem(
                    icon: "arrow.left",
                    label: "Swipe Left",
                    detail: "Edit / Delete",
                    color: .orange
                )
                Divider().frame(height: 40)
                gestureItem(
                    icon: "arrow.right",
                    label: "Swipe Right",
                    detail: "Toggle read",
                    color: .green
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }

    private func gestureItem(icon: String, label: String, detail: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(label)
                .font(.caption.bold())
            Text(detail)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Paper Row

struct PaperRow: View {
    let paper: Paper

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator bar
            RoundedRectangle(cornerRadius: 2)
                .fill(paper.status == .unread ? Color.accentColor : Color.green.opacity(0.5))
                .frame(width: 4, height: 50)

            VStack(alignment: .leading, spacing: 6) {
                Text(paper.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(paper.authors)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack {
                    if let journal = paper.journal {
                        Text(journal)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                    Text(String(paper.year))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let page = paper.pageNumber {
                        Text("p. \(page)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if let location = paper.locationName {
                        HStack(spacing: 2) {
                            Image(systemName: "mappin")
                                .font(.caption2)
                            Text(location)
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    }

                    // Status label instead of just a dot
                    Text(paper.status == .unread ? "Unread" : "Read")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(paper.status == .unread ? Color.accentColor.opacity(0.12) : Color.green.opacity(0.12))
                        .foregroundColor(paper.status == .unread ? .accentColor : .green)
                        .cornerRadius(4)
                }

                // Tags row
                if !paper.tagsList.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(paper.tagsList, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.15))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
