import SwiftUI
import LocalAuthentication
import FoldKit
import FoldL10n
import TestsKit

/// T7: asks for one Touch ID match. The plan only offers it on devices that report Touch ID,
/// so Face ID iPhones never show the system prompt (and no Face ID usage string is needed).
struct TouchIDTestView: View {
    let initialFoldState: FoldState
    let onFinish: (TestResult) -> Void
    let onCancel: () -> Void

    @Environment(\.appLanguage) private var language
    @State private var isScanning = false

    var body: some View {
        TestStepScreen(
            systemImage: "touchid",
            title: L10nKey.testTouchID.text(in: language),
            message: L10nKey.tidInstruction.text(in: language),
            onCancel: onCancel
        ) {
            EmptyView()
        } actions: {
            StepButton(title: L10nKey.tidScan.text(in: language)) {
                Task { await scan() }
            }
            .disabled(isScanning)
            .accessibilityIdentifier("touchID.scan")
        }
    }

    private func scan() async {
        isScanning = true
        defer { isScanning = false }
        let context = LAContext()
        // No passcode fallback: only the sensor itself counts.
        context.localizedFallbackTitle = ""
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            finish(Self.check(for: error))
            return
        }
        do {
            try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: L10nKey.tidReason.text(in: language)
            )
            finish(.matched)
        } catch let error as LAError where [.userCancel, .systemCancel, .appCancel].contains(error.code) {
            // Cancelled: stay on this screen so the user can try again or leave.
        } catch {
            finish(Self.check(for: error as NSError))
        }
    }

    /// Maps LocalAuthentication errors to the test's outcome categories.
    static func check(for error: NSError?) -> BiometricCheck {
        guard let error, error.domain == LAErrorDomain else { return .unavailable }
        switch LAError.Code(rawValue: error.code) {
        case .biometryNotEnrolled: return .notEnrolled
        case .biometryLockout: return .lockedOut
        case .authenticationFailed: return .notMatched
        default: return .unavailable
        }
    }

    private func finish(_ check: BiometricCheck) {
        let note: String
        switch check {
        case .matched: note = ""
        case .notEnrolled: note = L10nKey.tidNoteNotEnrolled.text(in: language)
        case .lockedOut: note = L10nKey.tidNoteLockedOut.text(in: language)
        case .notMatched: note = L10nKey.tidNoteNotMatched.text(in: language)
        case .unavailable: note = L10nKey.tidNoteUnavailable.text(in: language)
        }
        onFinish(check.result(notes: note))
    }
}

extension DeviceInfo {
    /// "touchID", "faceID", "opticID", or nil when the device has no biometrics.
    static var biometricType: String? {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .touchID: return "touchID"
        case .faceID: return "faceID"
        case .opticID: return "opticID"
        default: return nil
        }
    }
}
