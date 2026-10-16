import Foundation

/// The one-time purchase that unlocks reports, history and compare, monthly reminders and
/// the fold stats page (spec: "FoldCheck Reports", non-consumable).
public enum StoreProduct {
    public static let reportsID = "com.jackyu.foldcheck.reports"
}

/// What the entitlement rules need from a StoreKit transaction, so they can be tested
/// without StoreKit (and on Linux).
public struct TransactionSnapshot: Sendable, Equatable {
    public var productID: String
    /// StoreKit's `VerificationResult` was `.verified`.
    public var isVerified: Bool
    /// Set when Apple refunded or revoked the purchase.
    public var revocationDate: Date?

    public init(productID: String, isVerified: Bool, revocationDate: Date? = nil) {
        self.productID = productID
        self.isVerified = isVerified
        self.revocationDate = revocationDate
    }
}

public enum Entitlements {
    /// Unlocked only by a verified, unrevoked transaction for `productID`. An unverified
    /// transaction grants nothing, and a refund removes the unlock at once.
    public static func isUnlocked(_ productID: String, by transactions: [TransactionSnapshot]) -> Bool {
        transactions.contains { $0.productID == productID && $0.isVerified && $0.revocationDate == nil }
    }
}
