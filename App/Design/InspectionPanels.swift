import SwiftUI
import TestsKit

/// Layout follows available space, not hinge angles. On Duo, the system arrangement keeps
/// the panels clear of the fold. Each panel owns its scroll view: never nest ArrangementView
/// in a List or ScrollView. Each column scrolls independently at accessibility text sizes.
struct InspectionPanels<Primary: View, Secondary: View>: View {
    @State private var divisionFrame: CGRect?
    /// Opt in only for the dashboard overview; stacked layouts keep their shared scroller.
    var primaryScrollsOnlyWhenNeeded = false
    @ViewBuilder var primary: () -> Primary
    @ViewBuilder var secondary: () -> Secondary

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width >= 680 || divisionFrame != nil {
                arrangedPanels
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        primary()
                        secondary()
                    }
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                    .padding(20)
                }
                .accessibilityIdentifier("layout.stacked")
            }
        }
        .modifier(DivisionRegionObserver(frame: $divisionFrame))
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private var arrangedPanels: some View {
        #if FOLDCHECK_HINGE_API
        if #available(iOS 27.1, *) {
            ArrangementView {
                panel(primary, onlyWhenNeeded: primaryScrollsOnlyWhenNeeded)
            } secondary: {
                panel(secondary)
            }
            .arrangementViewStyle(.split)
            .accessibilityIdentifier("layout.split")
        } else {
            fallbackPanels
        }
        #else
        fallbackPanels
        #endif
    }

    private var fallbackPanels: some View {
        HStack(alignment: .top, spacing: 24) {
            panel(primary, onlyWhenNeeded: primaryScrollsOnlyWhenNeeded)
            panel(secondary)
        }
    }

    @ViewBuilder
    private func panel<Content: View>(_ content: @escaping () -> Content, onlyWhenNeeded: Bool = false) -> some View {
        if onlyWhenNeeded {
            FittingPanelScrollView {
                panelContent(content)
            }
        } else {
            ScrollView {
                panelContent(content)
            }
        }
    }

    private func panelContent<Content: View>(_ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            .padding(24)
    }
}

/// Keep the overview still when all of it fits, including its padding and the viewport's
/// safe areas. Re-evaluate after text, content, window or fold-layout changes.
private struct FittingPanelScrollView<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @State private var contentHeight: CGFloat?
    @State private var viewportHeight: CGFloat?

    private var fits: Bool {
        guard let contentHeight, let viewportHeight else { return false }
        return contentHeight <= viewportHeight
    }

    var body: some View {
        ScrollView {
            content()
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        // The proposed viewport size already excludes the navigation and home-indicator
        // safe areas. Subtracting safeAreaInsets again would incorrectly enable scrolling.
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewportHeight = $0 }
        .scrollDisabled(fits)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
    }
}

/// Include the inactive region so a flat inner display keeps its panel layout. Observe
/// geometry changes because Duo can report no reserved regions on its first layout pass.
private struct DivisionRegionObserver: ViewModifier {
    @Binding var frame: CGRect?

    func body(content: Content) -> some View {
        #if FOLDCHECK_HINGE_API
        if #available(iOS 27.1, *) {
            content.onGeometryChange(for: CGRect?.self) { proxy in
                proxy.reservedRegions(kind: .division, options: .includeInactive).first?.frame
            } action: { region in
                frame = region
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

enum InspectionStyle {
    // Dark enough for white button text in light and dark appearances.
    static let buttonFill = Color(red: 0.055, green: 0.39, blue: 0.25)
    static let tint = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.42, green: 0.86, blue: 0.66, alpha: 1)
            : UIColor(red: 0.055, green: 0.39, blue: 0.25, alpha: 1)
    })

    static func color(for outcome: TestOutcome) -> Color {
        switch outcome {
        case .pass: Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? .systemGreen : UIColor(red: 0.035, green: 0.38, blue: 0.20, alpha: 1) })
        case .attention: Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? .systemOrange : UIColor(red: 0.55, green: 0.29, blue: 0, alpha: 1) })
        case .fail: Color(.systemRed)
        case .skipped, .notApplicable, .unavailable: .secondary
        }
    }
}
