import XCTest
import FoldKit
import FoldL10n
import TestsKit
@testable import FoldCheck

final class FoldCheckTests: XCTestCase {
    @MainActor
    func testDeviceInfoComesFromTheDevice() {
        XCTAssertFalse(DeviceInfo.modelIdentifier.isEmpty)
        XCTAssertNotEqual(DeviceInfo.modelIdentifier, "arm64", "Simulator should report the simulated model")
        XCTAssertTrue(DeviceInfo.osVersion.contains(UIDevice.current.systemVersion))
        #if targetEnvironment(simulator)
        XCTAssertTrue(DeviceInfo.displayName.hasSuffix("(Simulator)"))
        #endif
    }

    @MainActor
    func testInspectionRequestUsesFoldStateForApplicability() {
        let noHinge = InspectionRequest.current(foldState: .noHinge)
        XCTAssertFalse(noHinge.context.hasHinge)
        let plan = InspectionPlan(tests: noHinge.tests, context: noHinge.context, implemented: InspectionTestRegistry.implemented)
        XCTAssertEqual(plan.runnable, [.touchGridOuter, .pixels])

        let open = InspectionRequest.current(foldState: FoldState(posture: .fullyOpen, angleDegrees: 180))
        let duoPlan = InspectionPlan(tests: open.tests, context: open.context, implemented: InspectionTestRegistry.implemented)
        XCTAssertEqual(duoPlan.runnable, [.touchGridOuter, .touchGridInner, .pixels, .crease, .hingeSweep])
    }

    func testMetricsFormatterForTouchGrid() {
        let result = TestResult(id: .touchGridInner, outcome: .pass, metrics: [
            TestMetricKey.coveragePercent: 100,
            TestMetricKey.cellsCovered: 372,
            TestMetricKey.totalCells: 372,
            TestMetricKey.creaseBandCoverage: 99.5,
            TestMetricKey.creaseBandCells: 246,
            TestMetricKey.creaseBandMissed: 1,
            TestMetricKey.maxTouches: 2,
        ])
        let lines = ResultMetricsFormatter.lines(for: result, language: .en)
        XCTAssertEqual(lines.map(\.value), ["100% (372/372)", "99.5% (245/246)", "2"])
        XCTAssertEqual(
            ResultMetricsFormatter.summary(for: result, language: .en),
            "Coverage 100% (372/372) · Crease band 99.5% (245/246) · Max touches 2"
        )
    }

    func testMetricsFormatterForPixelsAndCrease() {
        let pixels = TestResult(id: .pixels, outcome: .attention, metrics: [TestMetricKey.issuesMarked: 3])
        XCTAssertEqual(ResultMetricsFormatter.summary(for: pixels, language: .en), "Issues marked 3")

        let crease = TestResult(id: .crease, outcome: .pass, metrics: [
            TestMetricKey.creaseRating: 2.3,
            TestMetricKey.creaseRatingMax: 3,
            TestMetricKey.photoAttached: 0,
        ])
        XCTAssertEqual(ResultMetricsFormatter.lines(for: crease, language: .en).map(\.value), ["2.3 / 5 (max 3)"])

        let skipped = TestResult.skipped(id: .cameras)
        XCTAssertNil(ResultMetricsFormatter.summary(for: skipped, language: .en))
    }
}
