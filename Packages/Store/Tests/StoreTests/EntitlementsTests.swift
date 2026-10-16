import Testing
import Foundation
@testable import Store

@Suite("Store gating (AC8)")
struct EntitlementsTests {
    let id = StoreProduct.reportsID

    @Test("Nothing bought is locked")
    func empty() {
        #expect(!Entitlements.isUnlocked(id, by: []))
    }

    @Test("A verified purchase unlocks")
    func verified() {
        #expect(Entitlements.isUnlocked(id, by: [TransactionSnapshot(productID: id, isVerified: true)]))
    }

    @Test("An unverified transaction grants nothing")
    func unverified() {
        #expect(!Entitlements.isUnlocked(id, by: [TransactionSnapshot(productID: id, isVerified: false)]))
    }

    @Test("A refund removes the unlock")
    func refunded() {
        let refunded = TransactionSnapshot(productID: id, isVerified: true, revocationDate: Date())
        #expect(!Entitlements.isUnlocked(id, by: [refunded]))
    }

    @Test("Another product doesn't unlock reports")
    func otherProduct() {
        #expect(!Entitlements.isUnlocked(id, by: [TransactionSnapshot(productID: "com.example.other", isVerified: true)]))
    }

    #if canImport(StoreKit)
    @MainActor
    @Test("The cached unlock shows before StoreKit answers; -UnlockReports forces it in DEBUG")
    func cache() throws {
        let defaults = try #require(UserDefaults(suiteName: "StoreTests-\(UUID().uuidString)"))
        #expect(!Store(defaults: defaults, arguments: []).hasReports)
        defaults.set(true, forKey: Store.cacheKey)
        #expect(Store(defaults: defaults, arguments: []).hasReports)

        let fresh = try #require(UserDefaults(suiteName: "StoreTests-\(UUID().uuidString)"))
        #if DEBUG
        #expect(Store(defaults: fresh, arguments: ["-UnlockReports"]).hasReports)
        #endif
    }
    #endif
}
