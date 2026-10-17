import SwiftUI
import UIKit
import TestsKit
import FoldL10n

/// Keep the runner mounted while blocking interaction, so resizing never erases coverage.
struct InspectionWindowGuard: ViewModifier {
    let isRunning: Bool
    @Environment(\.appLanguage) private var language
    @State private var viewport: InspectionViewport = .fullScreen

    func body(content: Content) -> some View {
        content
            .allowsHitTesting(viewport != .requiresFullScreen)
            .accessibilityHidden(viewport == .requiresFullScreen)
            .background(WindowBoundsProbe { viewport = $0 })
            .overlay {
                if viewport == .requiresFullScreen {
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right").font(.largeTitle)
                        Text(L10nKey.windowFullScreenTitle.text(in: language)).font(.title2.bold())
                        Text(L10nKey.windowFullScreenMessage.text(in: language)).multilineTextAlignment(.center)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.regularMaterial)
                    .accessibilityIdentifier("inspection.fullScreenRequired")
                }
            }
            .safeAreaInset(edge: .top) {
                if viewport == .iPadCompatibility && !isRunning {
                    Label(L10nKey.windowIPadWarning.text(in: language), systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial)
                        .accessibilityIdentifier("inspection.compatibilityWarning")
                }
            }
    }
}

private struct WindowBoundsProbe: UIViewRepresentable {
    let onChange: (InspectionViewport) -> Void

    func makeUIView(context: Context) -> ProbeView { ProbeView() }
    func updateUIView(_ view: ProbeView, context: Context) {
        view.onChange = onChange
        view.measure()
    }

    final class ProbeView: UIView {
        var onChange: ((InspectionViewport) -> Void)?
        private var last: InspectionViewport?

        override func didMoveToWindow() { super.didMoveToWindow(); measure() }
        override func layoutSubviews() { super.layoutSubviews(); measure() }

        func measure() {
            guard let window, let screen = window.windowScene?.screen else { return }
            var result = InspectionViewport.evaluate(
                window: window.convert(window.bounds, to: screen.coordinateSpace),
                screen: screen.bounds,
                isIPad: UIDevice.current.userInterfaceIdiom == .pad || DeviceInfo.modelIdentifier.hasPrefix("iPad")
            )
            #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-UITestMode"), let index = args.firstIndex(of: "-WindowTestMode"), index + 1 < args.count {
                result = args[index + 1] == "ipad" ? .iPadCompatibility : .requiresFullScreen
            }
            #endif
            guard result != last else { return }
            last = result
            DispatchQueue.main.async { [weak self] in self?.onChange?(result) }
        }
    }
}
