import SwiftUI

@main
struct ScholarSyncApp: App {
    @StateObject private var viewModel = QueueViewModel()
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var offlineManager = OfflineManager.shared
    @State private var isLoggedIn = SupabaseManager.shared.isAuthenticated
    @State private var hasCheckedAuth = false

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasCheckedAuth {
                    ProgressView("Loading...")
                } else if isLoggedIn {
                    ZStack(alignment: .top) {
                        ContentView(isLoggedIn: $isLoggedIn)
                            .environmentObject(viewModel)
                            .environmentObject(storeManager)

                        // Offline banner
                        if !offlineManager.isOnline {
                            HStack(spacing: 8) {
                                Image(systemName: "wifi.slash")
                                    .font(.caption)
                                Text("Offline — changes will sync when back online")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .animation(.easeInOut, value: offlineManager.isOnline)
                        }
                    }
                } else {
                    LoginView(isLoggedIn: $isLoggedIn)
                }
            }
            .task {
                if SupabaseManager.shared.isAuthenticated {
                    let refreshed = await SupabaseManager.shared.refreshAccessToken()
                    isLoggedIn = refreshed
                } else {
                    isLoggedIn = false
                }
                hasCheckedAuth = true
            }
        }
        .handlesExternalEvents(matching: ["*"])
    }
}
