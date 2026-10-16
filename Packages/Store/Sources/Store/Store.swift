#if canImport(StoreKit)
import Foundation
import Observation
import StoreKit

/// StoreKit 2 for the "FoldCheck Reports" unlock (spec §StoreKit): loads the product, listens
/// for transaction updates from launch, and recomputes the unlock from
/// `Transaction.currentEntitlements`. Unverified transactions grant nothing; refunds remove
/// the unlock. The last result is cached only so a returning buyer doesn't see a paywall flash.
@MainActor
@Observable
public final class Store {
    public enum LoadState: Equatable, Sendable {
        case loading, loaded, unavailable
    }

    public enum PurchaseState: Equatable, Sendable {
        case idle
        case purchasing
        /// Ask to Buy or extra authentication: waiting for someone to approve.
        case pending
        case failed
    }

    public private(set) var product: Product?
    public private(set) var loadState: LoadState = .loading
    public private(set) var purchaseState: PurchaseState = .idle
    /// Reports, history and compare, reminders and fold stats are unlocked.
    public private(set) var hasReports: Bool

    static let cacheKey = "store.hasReports"
    private let defaults: UserDefaults
    private let forcedUnlock: Bool
    private var updates: Task<Void, Never>?

    /// - Parameter arguments: in DEBUG builds `-UnlockReports` unlocks everything for UI tests.
    public init(defaults: UserDefaults = .standard, arguments: [String] = ProcessInfo.processInfo.arguments) {
        self.defaults = defaults
        #if DEBUG
        forcedUnlock = arguments.contains("-UnlockReports")
        #else
        forcedUnlock = false
        #endif
        hasReports = forcedUnlock || defaults.bool(forKey: Self.cacheKey)
    }

    /// Call once at launch: starts the update listener, loads the product and the unlock.
    public func start() async {
        if updates == nil {
            updates = Task { [weak self] in
                for await result in Transaction.updates {
                    if case .verified(let transaction) = result {
                        await transaction.finish()
                    }
                    await self?.refreshEntitlements()
                }
            }
        }
        await loadProduct()
        await refreshEntitlements()
    }

    public func loadProduct() async {
        loadState = .loading
        do {
            product = try await Product.products(for: [StoreProduct.reportsID]).first
            loadState = product == nil ? .unavailable : .loaded
        } catch {
            loadState = .unavailable
        }
    }

    public func refreshEntitlements() async {
        var snapshots: [TransactionSnapshot] = []
        for await result in Transaction.currentEntitlements {
            snapshots.append(Self.snapshot(of: result))
        }
        apply(Entitlements.isUnlocked(StoreProduct.reportsID, by: snapshots))
    }

    public func purchase() async {
        guard let product else { return }
        purchaseState = .purchasing
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                await refreshEntitlements()
                purchaseState = .idle
            case .success(.unverified):
                purchaseState = .failed
            case .pending:
                purchaseState = .pending
            case .userCancelled:
                purchaseState = .idle
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed
        }
    }

    /// "Restore Purchases": asks the App Store to sync, then recomputes. Returns the unlock.
    @discardableResult
    public func restore() async -> Bool {
        try? await AppStore.sync()
        await refreshEntitlements()
        return hasReports
    }

    private func apply(_ unlocked: Bool) {
        defaults.set(unlocked, forKey: Self.cacheKey)
        hasReports = forcedUnlock || unlocked
    }

    private static func snapshot(of result: VerificationResult<Transaction>) -> TransactionSnapshot {
        switch result {
        case .verified(let transaction):
            return TransactionSnapshot(productID: transaction.productID, isVerified: true, revocationDate: transaction.revocationDate)
        case .unverified(let transaction, _):
            return TransactionSnapshot(productID: transaction.productID, isVerified: false, revocationDate: transaction.revocationDate)
        }
    }
}
#endif
