import XCTest
import StoreKitTest
@testable import FoldCheck
import Store

/// AC8 with StoreKit's local test environment (Configuration.storekit): purchase, refund,
/// Ask to Buy and a failed purchase.
@MainActor
final class StorePurchaseTests: XCTestCase {
    private var session: SKTestSession!

    override func setUp() async throws {
        session = try SKTestSession(configurationFileNamed: "Configuration")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
    }

    override func tearDown() async throws {
        // Do not leave the restore test's purchase active for subsequent free-user UI tests.
        session?.clearTransactions()
        session = nil
        try await super.tearDown()
    }

    /// StoreKit's local test environment only serves apps installed for development. A
    /// command-line build signed "to run locally" isn't one (storekitd logs "not installed for
    /// development" and returns no products), so these tests skip there and run from Xcode
    /// with a development team.
    private func makeStore() async throws -> Store {
        let defaults = UserDefaults(suiteName: "StorePurchaseTests-\(UUID().uuidString)")!
        let store = Store(defaults: defaults, arguments: [])
        await store.start()
        guard store.loadState == .loaded else {
            throw XCTSkip("StoreKit test environment unavailable: no products from Configuration.storekit")
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
        await store.purchase()
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
        await store.purchase()
        XCTAssertEqual(store.purchaseState, .pending)
        XCTAssertFalse(store.hasReports)
    }

    func testFailedPurchaseUnlocksNothing() async throws {
        session.failTransactionsEnabled = true
        let store = try await makeStore()
        await store.purchase()
        XCTAssertEqual(store.purchaseState, .failed)
        XCTAssertFalse(store.hasReports)
    }

    func testRestoreFindsAnEarlierPurchase() async throws {
        let store = try await makeStore()
        try await session.buyProduct(identifier: StoreProduct.reportsID)
        let restored = await store.restore()
        XCTAssertTrue(restored)
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
