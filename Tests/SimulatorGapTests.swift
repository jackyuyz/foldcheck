import XCTest
import AVFoundation
import FoldKit
import TestsKit
@testable import FoldCheck

final class SimulatorGapTests: XCTestCase {
    func testAutoCompleteRequiresExplicitUITestModeAndPass() {
        #if DEBUG
        XCTAssertFalse(UITestConfiguration.autoCompletesTests(arguments: ["-AutoCompleteTests", "pass"]))
        XCTAssertFalse(UITestConfiguration.autoCompletesTests(arguments: ["-UITestMode", "1", "-AutoCompleteTests"]))
        XCTAssertFalse(UITestConfiguration.autoCompletesTests(arguments: ["-UITestMode", "1", "-AutoCompleteTests", "fail"]))
        XCTAssertTrue(UITestConfiguration.autoCompletesTests(arguments: ["-UITestMode", "1", "-AutoCompleteTests", "pass"]))
        #endif
    }

    func testDuoDiscoveryTypesAreIncludedWhereAvailable() {
        #if FOLDCHECK_HINGE_API
        if #available(iOS 27.1, *) {
            XCTAssertTrue(CameraFrameSource.deviceTypes.contains(.builtInInnerUltraWideCamera))
            XCTAssertTrue(CameraFrameSource.deviceTypes.contains(.builtInOuterUltraWideCamera))
        }
        #endif
        XCTAssertTrue(CameraFrameSource.deviceTypes.contains(.builtInWideAngleCamera))
    }

    @MainActor
    func testSimulatorDoesNotClaimAnEarpieceRoute() {
        #if targetEnvironment(simulator)
        XCTAssertFalse(AudioTestController().prepareReceiver())
        #endif
    }
}
