import Foundation

/// Whether PDF reports are unlocked (spec F2: a one-time purchase).
///
/// StoreKit arrives in M6. Until then DEBUG builds treat reports as unlocked so the report
/// and verify flow can be built and tested, and release builds show the paywall.
enum ReportAccess {
    static var isUnlocked: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
