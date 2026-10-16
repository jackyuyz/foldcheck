import SwiftUI
import UIKit
import FoldL10n
import TestsKit

/// Layout for the step-by-step hardware tests (T5–T9): cancel, the step counter, an icon,
/// the instruction, optional live content, and the step's buttons at the bottom.
struct TestStepScreen<Content: View, Actions: View>: View {
    var step: (current: Int, total: Int)?
    let systemImage: String
    let title: String
    var message: String?
    let onCancel: () -> Void
    @ViewBuilder var content: () -> Content
    @ViewBuilder var actions: () -> Actions

    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(Text(L10nKey.inspectionCancel.text(in: language)))
                .accessibilityIdentifier("test.cancel")
                Spacer()
                if let step {
                    Text(L10nKey.testStep.text(in: language, step.current, step.total))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("test.step")
                }
            }
            .padding(.horizontal)

            ScrollView {
                VStack(spacing: 16) {
                    Image(systemName: systemImage)
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)
                        .padding(.top, 24)
                        .accessibilityHidden(true)
                    Text(title)
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                    if let message {
                        Text(message)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    content()
                }
                .padding()
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }

            VStack(spacing: 10) {
                actions()
            }
            .padding()
            .frame(maxWidth: 520)
        }
    }
}

/// A full-width button; `prominent` for the step's main action.
struct StepButton: View {
    let title: String
    var prominent = true
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .modifier(StepButtonStyle(prominent: prominent))
    }
}

private struct StepButtonStyle: ViewModifier {
    let prominent: Bool

    func body(content: Content) -> some View {
        if prominent {
            content.buttonStyle(.borderedProminent)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}

/// Yes / No answer row used by the confirmation steps.
struct YesNoButtons: View {
    var identifier: String
    let onAnswer: (Bool) -> Void
    @Environment(\.appLanguage) private var language

    var body: some View {
        HStack(spacing: 12) {
            StepButton(title: L10nKey.testNo.text(in: language), prominent: false) { onAnswer(false) }
                .accessibilityIdentifier("\(identifier).no")
            StepButton(title: L10nKey.testYes.text(in: language)) { onAnswer(true) }
                .accessibilityIdentifier("\(identifier).yes")
        }
    }
}

/// Shown when a permission is off: the test ends as Skipped with `reason`, and the user can
/// jump to FoldCheck's page in Settings.
struct PermissionDeniedScreen: View {
    let systemImage: String
    let reason: String
    let onSkip: () -> Void
    let onCancel: () -> Void
    @Environment(\.appLanguage) private var language
    @Environment(\.openURL) private var openURL

    var body: some View {
        TestStepScreen(systemImage: systemImage, title: reason, onCancel: onCancel) {
            EmptyView()
        } actions: {
            StepButton(title: L10nKey.testOpenSettings.text(in: language), prominent: false) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .accessibilityIdentifier("test.openSettings")
            StepButton(title: L10nKey.testContinue.text(in: language), action: onSkip)
                .accessibilityIdentifier("test.permissionContinue")
        }
    }
}

extension Array where Element == String {
    /// "A, B, C" in the app's language.
    func listed(in language: AppLanguage) -> String {
        formatted(.list(type: .and).locale(Locale(identifier: language.localeIdentifier)))
    }
}
