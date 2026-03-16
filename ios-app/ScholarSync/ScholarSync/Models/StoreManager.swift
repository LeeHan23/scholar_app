import Foundation
import Combine
import StoreKit

@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()

    static let monthlyProductId = "com.scholarsync.pro.monthly"
    static let yearlyProductId = "com.scholarsync.pro.yearly"

    @Published var isPro: Bool = false
    @Published var capturesCount: Int = 0
    @Published var products: [Product] = []
    @Published var purchaseError: String?

    let freeTierLimit = 15

    private var transactionListener: Task<Void, Never>?

    private init() {
        self.capturesCount = UserDefaults.standard.integer(forKey: "capturesCount")
        transactionListener = listenForTransactions()

        Task {
            await fetchProducts()
            await updateEntitlements()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Products

    func fetchProducts() async {
        do {
            let fetched = try await Product.products(for: [
                Self.monthlyProductId,
                Self.yearlyProductId
            ])
            products = fetched.sorted { $0.price < $1.price }
        } catch {
            print("Failed to fetch products: \(error)")
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        purchaseError = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updateEntitlements()

            case .userCancelled:
                break

            case .pending:
                purchaseError = "Purchase is pending approval."

            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
            print("Purchase failed: \(error)")
        }
    }

    func purchasePro() async {
        // Purchase the monthly product by default
        guard let monthly = products.first(where: { $0.id == Self.monthlyProductId }) else {
            purchaseError = "Product not available. Please try again later."
            return
        }
        await purchase(monthly)
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await updateEntitlements()
    }

    // MARK: - Entitlements

    func updateEntitlements() async {
        var hasActiveSub = false

        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if transaction.productID == Self.monthlyProductId ||
                   transaction.productID == Self.yearlyProductId {
                    hasActiveSub = true
                }
            }
        }

        isPro = hasActiveSub
    }

    // MARK: - Capture Gating

    func canCapture() -> Bool {
        if isPro { return true }
        return capturesCount < freeTierLimit
    }

    func incrementCapture() {
        capturesCount += 1
        UserDefaults.standard.set(capturesCount, forKey: "capturesCount")
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if let transaction = try? self?.checkVerified(result) {
                    await transaction.finish()
                    await self?.updateEntitlements()
                }
            }
        }
    }

    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
