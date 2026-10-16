import Foundation
import FoldKit

public extension DisplayKind {
    /// Which display the app is (assumed to be) on for a posture. `closed` → outer,
    /// open or flexed → inner. `nil` for a device without a hinge or an unknown posture.
    /// Heuristic from the spec: there is no public "which display am I on" API.
    init?(posture: FoldPosture) {
        switch posture {
        case .closed: self = .outer
        case .partiallyOpen, .fullyOpen: self = .inner
        case .noHinge, .unknown: return nil
        }
    }
}

public extension TestID {
    /// Whether the test can run on this device. Hinge tests are N/A without a hinge, and the
    /// Touch ID test is N/A on a device without Touch ID (Face ID iPhones).
    func isApplicable(_ context: DeviceContext) -> Bool {
        if self == .touchID { return context.hasTouchID }
        return !requiresHinge || context.hasHinge
    }

    /// The display this test is meant to run on, on a Duo.
    var intendedDisplay: DisplayKind? {
        switch self {
        case .touchGridOuter: return .outer
        case .touchGridInner, .crease: return .inner
        default: return nil
        }
    }
}

/// Which tests an inspection steps through, and which are recorded without running.
public struct InspectionPlan: Sendable, Equatable {
    /// Tests the user steps through, in order.
    public var runnable: [TestID]
    /// Tests that don't apply to this device (recorded as Not applicable).
    public var notApplicable: [TestID]
    /// Applicable tests this build can't run yet (recorded as Skipped).
    public var unavailable: [TestID]

    /// - Parameters:
    ///   - tests: Requested tests in order (the full inspection, or a single quick test).
    ///   - context: Device and fold state at the start.
    ///   - implemented: Tests this build has screens for.
    public init(tests: [TestID] = TestID.defaultOrder, context: DeviceContext, implemented: Set<TestID>) {
        var runnable: [TestID] = []
        var notApplicable: [TestID] = []
        var unavailable: [TestID] = []
        for test in tests {
            if !test.isApplicable(context) {
                notApplicable.append(test)
            } else if implemented.contains(test) {
                runnable.append(test)
            } else {
                unavailable.append(test)
            }
        }
        self.runnable = runnable
        self.notApplicable = notApplicable
        self.unavailable = unavailable
    }

    /// The touch grid a quick "Touch test" should run: the inner grid when a Duo is open,
    /// otherwise the outer (or only) display.
    public static func quickTouchTest(for context: DeviceContext) -> TestID {
        DisplayKind(posture: context.foldState.posture) == .inner ? .touchGridInner : .touchGridOuter
    }
}
