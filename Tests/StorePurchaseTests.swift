import XCTest
import StoreKitTest
@testable import FoldCheck
import Store

/// AC8 with StoreKit's local test environment (Configuration.storekit): purchase, refund,
/// Ask to Buy and a failed purchase.
@MainActor
final class StorePurchaseTests: XCTestCase {
    private var session: SKTestSession!
    private var stores: [Store] = []

    private enum TestError: Error { case timedOut, productsUnavailable }

    /// StoreKit operations can outlive cancellation. An unstructured task and an XCTest
    /// deadline let the test fail without waiting forever for a task group's child to exit.
    private func complete(_ name: String = "operation", _ operation: @escaping @MainActor () async throws -> Void) async throws {
        let completed = expectation(description: "StoreKit \(name) completed")
        var finished = false
        var failure: Error?
        let task = Task { @MainActor in
            do { try await operation() } catch { failure = error }
            finished = true
            completed.fulfill()
        }
        await fulfillment(of: [completed], timeout: 15)
        task.cancel()
        guard finished else { throw TestError.timedOut }
        if let failure { throw failure }
    }

    override func setUp() async throws {
        session = try SKTestSession(configurationFileNamed: "Configuration")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
    }

    override func tearDown() async throws {
        stores.forEach { $0.stop() }
        stores = []
        // Do not leave the restore test's purchase active for subsequent free-user UI tests.
        session?.clearTransactions()
        session?.resetToDefaultState()
        session = nil
        try await super.tearDown()
    }

    /// A missing local product is a configuration failure, never a passing/skipped purchase
    /// suite. The simulator uses the bundled configuration, without an App Store account.
    private func makeStore() async throws -> Store {
        let defaults = UserDefaults(suiteName: "StorePurchaseTests-\(UUID().uuidString)")!
        let store = Store(defaults: defaults, arguments: [])
        stores.append(store)
        try await complete("start store") { await store.start() }
        guard store.loadState == .loaded else {
            XCTFail("No local StoreKit product from Configuration.storekit")
            throw TestError.productsUnavailable
        }
        return store
    }

    func testProductLoadsWithAStorePrice() async throws {
        let store = try await makeStore()
        XCTAssertEqual(store.loadState, .loaded)
        XCTAssertEqual(store.product?.id, StoreProduct.reportsID)
        XCTAssertFalse(store.product?.displayPrice.isEmpty ?? true)
        XCTAssertFalse(store.hasReports)
    }

    func testPurchaseUnlocksAndRefundLocks() async throws {
        let store = try await makeStore()
        try await complete("purchase") { await store.purchase() }
        XCTAssertTrue(store.hasReports)
        XCTAssertEqual(store.purchaseState, .idle)

        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.refundTransaction(identifier: transaction.identifier)
        // SKTestSession can return before storekitd publishes the revoked entitlement.
        // Poll the observable result with a bound while the launch listener also refreshes it.
        for _ in 0..<50 {
            await store.refreshEntitlements()
            if !store.hasReports { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertFalse(store.hasReports)
    }

    func testAskToBuyWaitsForApproval() async throws {
        session.askToBuyEnabled = true
        let store = try await makeStore()
        try await complete("purchase") { await store.purchase() }
        XCTAssertEqual(store.purchaseState, .pending)
        XCTAssertFalse(store.hasReports)

        let pending = try XCTUnwrap(session.allTransactions().first { $0.pendingAskToBuyConfirmation })
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        // Deliberately don't call refreshEntitlements: approval must reach the launch listener.
        try await complete("approval update") {
            while !store.hasReports { try await Task.sleep(for: .milliseconds(50)) }
        }
        XCTAssertEqual(store.purchaseState, .idle)
    }

    func testAskToBuyDeclinedUnlocksNothing() async throws {
        session.askToBuyEnabled = true
        let store = try await makeStore()
        try await complete("purchase") { await store.purchase() }
        XCTAssertEqual(store.purchaseState, .pending)
        XCTAssertFalse(store.hasReports)
        let pending = try XCTUnwrap(session.allTransactions().first { $0.pendingAskToBuyConfirmation })
        try session.declineAskToBuyTransaction(identifier: pending.identifier)
        try await complete("refresh entitlements") { await store.refreshEntitlements() }
        XCTAssertFalse(store.hasReports)
    }

    func testFailedPurchaseUnlocksNothing() async throws {
        try await session.setSimulatedError(.generic(.unknown), forAPI: .purchase)
        let store = try await makeStore()
        try await complete("purchase") { await store.purchase() }
        XCTAssertEqual(store.purchaseState, .failed)
        XCTAssertFalse(store.hasReports)
    }

    func testRestoreFindsAnEarlierPurchase() async throws {
        let store = try await makeStore()
        try await complete("external local purchase") { try await self.session.buyProduct(identifier: StoreProduct.reportsID) }
        try await complete("restore") {
            let restored = await store.restore()
            XCTAssertTrue(restored)
        }
    }
}

final class MonthlyReminderTests: XCTestCase {
    func testSameDayEachMonthAtTen() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        let october16 = calendar.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 15))!
        let components = MonthlyReminder.components(startingFrom: october16, calendar: calendar)
        XCTAssertEqual(components.day, 16)
        XCTAssertEqual(components.hour, 10)
        XCTAssertEqual(components.minute, 0)
        XCTAssertNil(components.month, "Repeats every month")
    }

    func testLateDaysMoveTo28SoEveryMonthFires() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let january31 = calendar.date(from: DateComponents(year: 2027, month: 1, day: 31, hour: 9))!
        XCTAssertEqual(MonthlyReminder.components(startingFrom: january31, calendar: calendar).day, 28)
    }
}
