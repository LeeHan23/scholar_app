import Foundation
import Combine

@MainActor
class QueueViewModel: ObservableObject {
    @Published var queue: [Paper] = []
    @Published var isScanning = false
    @Published var scannedCode: String? = nil {
        didSet {
            if let code = scannedCode {
                Task {
                    await handleScannedCode(code)
                }
            }
        }
    }
    
    func handleScannedCode(_ code: String) async {
        isScanning = false // dismiss scanner
        
        do {
            // For this project portfolio, we fetch directly using the CrossrefService
            // If it's a barcode (ISBN), we would map to a book API, but here we assume DOI
            let newPaper = try await CrossrefService.shared.fetchPaper(doi: code)
            queue.insert(newPaper, at: 0)
            
            // Later: Sync this new paper up to Supabase so it appears on Web extension
        } catch {
            print("Failed to fetch paper for code \(code): \(error)")
        }
    }
}
