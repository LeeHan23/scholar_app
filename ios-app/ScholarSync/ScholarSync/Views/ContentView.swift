import SwiftUI

struct ContentView: View {
    @EnvironmentObject var queueViewModel: QueueViewModel
    @EnvironmentObject var storeManager: StoreManager
    @State private var showingScanner = false
    
    var body: some View {
        NavigationView {
            List {
                if queueViewModel.queue.isEmpty {
                    VStack(alignment: .center, spacing: 16) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No papers yet.")
                            .font(.headline)
                        Text("Tap the scan button to capture a DOI or ISBN.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(queueViewModel.queue) { paper in
                        PaperRow(paper: paper)
                    }
                }
            }
            .navigationTitle("Reading Queue")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if storeManager.canCapture() {
                            showingScanner = true
                        } else {
                            // In a real app, show pro upgrade paywall
                            print("Needs Pro Upgrade")
                        }
                    }) {
                        Image(systemName: "qrcode.viewfinder")
                    }
                }
            }
            .sheet(isPresented: $showingScanner) {
                // The ScannerView expects a binding to scannedCode. 
                // We'll map it to the ViewModel's logic.
                ScannerViewWrapper(isPresented: $showingScanner)
            }
        }
    }
}

// Wrapper to bridge ScannerView to ViewModel
struct ScannerViewWrapper: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var queueViewModel: QueueViewModel
    @State private var localScannedCode: String?
    
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
                        StoreManager.shared.incrementCapture()
                        Task {
                            await queueViewModel.handleScannedCode(code)
                        }
                    }
                }
        }
    }
}

struct PaperRow: View {
    let paper: Paper
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(paper.title)
                .font(.headline)
                .lineLimit(2)
            
            Text(paper.authors.joined(separator: ", "))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            HStack {
                if let journal = paper.journal {
                    Text(journal)
                        .font(.caption)
                        .padding(4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
                Text(String(paper.year))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if paper.status == .unread {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
