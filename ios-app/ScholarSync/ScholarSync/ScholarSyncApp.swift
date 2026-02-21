import SwiftUI

@main
struct ScholarSyncApp: App {
    @StateObject private var queueViewModel = QueueViewModel()
    @StateObject private var storeManager = StoreManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(queueViewModel)
                .environmentObject(storeManager)
        }
    }
}
