import XCTest
import SwiftUI
import WidgetKit
import Library
import TestsKit
import FoldL10n

/// These attachments render the same view as the extension. Review them in addition to a
/// real SpringBoard widget; they do not reproduce the system gallery, tinting or privacy UI.
@MainActor
final class WidgetRenderingTests: XCTestCase {
    func testWidgetLayoutsForVisualReview() throws {
        for language in [AppLanguage.en, .zhHans] {
            let session = InspectionSession(deviceModel: "Sample", osVersion: "27.1", hasHinge: true,
                results: [TestResult(id: .hingeSweep, outcome: .attention), TestResult(id: .pixels, outcome: .pass)])
            let snapshot = WidgetHealthSnapshot(health: DeviceHealth(sessions: [session], context: .mock(hasHinge: true)), languageCode: language.rawValue)
            for (family, size, name) in [
                (WidgetFamily.systemSmall, CGSize(width: 170, height: 170), "small"),
                (.systemMedium, CGSize(width: 360, height: 170), "medium"),
                (.accessoryRectangular, CGSize(width: 180, height: 84), "lock-screen"),
            ] {
                for dark in [false, true] {
                    let view = HealthWidgetView(snapshot: snapshot, family: family)
                        .environment(\.colorScheme, dark ? .dark : .light)
                        .frame(width: size.width - 32, height: size.height - 32)
                        .padding(16)
                        .background(dark ? Color.black : Color.white)
                    let renderer = ImageRenderer(content: view)
                    renderer.scale = 3
                    let image = try XCTUnwrap(renderer.uiImage)
                    XCTAssertGreaterThan(image.size.width, 0)
                    let attachment = XCTAttachment(image: image)
                    attachment.name = "widget-\(language.rawValue)-\(name)-\(dark ? "dark" : "light")"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
        }
    }
}
