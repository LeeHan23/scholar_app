import Foundation
// In a real app: import RevenueCat

@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    @Published var isPro: Bool = false
    @Published var capturesCount: Int = 0
    let freeTierLimit = 15
    
    private init() {
        // Load captures count from UserDefaults/Supabase
        self.capturesCount = UserDefaults.standard.integer(forKey: "capturesCount")
        // Check active subscriptions via RevenueCat (Purchases.shared.getCustomerInfo)
    }
    
    func canCapture() -> Bool {
        if isPro { return true }
        return capturesCount < freeTierLimit
    }
    
    func incrementCapture() {
        capturesCount += 1
        UserDefaults.standard.set(capturesCount, forKey: "capturesCount")
    }
    
    func purchasePro() async {
        // For portfolio: Mock the RevenueCat purchase completion
        // Purchases.shared.purchase(package: proPackage) { ... }
        isPro = true
        print("Unlocked ScholarSync Pro! Unlimited caps.")
    }
    
    func restorePurchases() async {
        // Purchases.shared.restorePurchases { ... }
    }
}
