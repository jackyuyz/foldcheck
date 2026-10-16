import UIKit
import CoreImage.CIFilterBuiltins
import FoldL10n
import TestsKit
import ReportKit

/// Draws the report PDF (spec F2): device, summary, every result with its metrics, notes,
/// hinge chart and photos, then the signature with its QR code and the disclaimer. The signed
/// bundle goes in the document Subject so Verify can check an imported PDF offline (AC4).
struct ReportPDFRenderer {
    let session: InspectionSession
    let content: ReportContent
    let bundle: ReportBundle
    let language: AppLanguage

    static let pageSize = CGSize(width: 612, height: 792)  // US Letter, 72 dpi
    private static let margin: CGFloat = 48

    func render() throws -> Data {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: content.title,
            kCGPDFContextCreator as String: "FoldCheck",
            kCGPDFContextSubject as String: try bundle.pdfMetadataString(),
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: Self.pageSize), format: format)
        return renderer.pdfData { context in
            var page = PageWriter(context: context, language: language, reportID: content.reportID)
            page.begin()
            drawHeader(&page)
            drawDevice(&page)
            drawSummary(&page)
            drawResults(&page)
            drawSignature(&page)
            page.text(content.disclaimer, font: .systemFont(ofSize: 8), color: PDFColor.secondary)
        }
    }

    // MARK: Sections

    private func drawHeader(_ page: inout PageWriter) {
        page.text(content.title, font: .boldSystemFont(ofSize: 20))
        page.text(L10nKey.reportGenerated.text(in: language, content.generatedAt), font: .systemFont(ofSize: 10), color: PDFColor.secondary, after: 2)
        page.text("\(L10nKey.reportTimeZone.text(in: language)): \(content.timeZone)", font: .systemFont(ofSize: 10), color: PDFColor.secondary, after: 2)
        page.text("\(L10nKey.verifyReportID.text(in: language)): \(content.reportID)", font: .monospacedSystemFont(ofSize: 9, weight: .regular), color: PDFColor.secondary, after: 2)
        page.rule()
    }

    private func drawDevice(_ page: inout PageWriter) {
        page.heading(L10nKey.reportDeviceInfo.text(in: language))
        page.pairs([
            (L10nKey.reportModel.text(in: language), content.deviceModel),
            (L10nKey.reportType.text(in: language), content.deviceType),
            (L10nKey.debugIos.text(in: language), content.osVersion),
            (L10nKey.reportStorage.text(in: language), content.storageCapacity ?? L10nKey.reportUnknown.text(in: language)),
        ])
        page.rule()
    }

    private func drawSummary(_ page: inout PageWriter) {
        page.heading(L10nKey.reportSummary.text(in: language))
        var pairs = [(L10nKey.reportStatus.text(in: language), content.overallStatus)]
        if let score = content.overallScore { pairs.append((L10nKey.reportScore.text(in: language), score)) }
        if let duration = content.inspectionDuration { pairs.append((L10nKey.reportDuration.text(in: language), duration)) }
        pairs.append((L10nKey.reportInspectionDate.text(in: language), content.inspectionDate))
        page.pairs(pairs)
        page.rule()
    }

    private func drawResults(_ page: inout PageWriter) {
        page.heading(L10nKey.reportResults.text(in: language))
        for result in session.results {
            page.ensureSpace(60)
            let name = result.id.localizedName(in: language, hasHinge: session.hasHinge)
            page.titleWithBadge(name, badge: result.outcome.localizedName(in: language), color: Self.color(for: result.outcome))
            if let display = result.display {
                page.text(display.localizedName(in: language), font: .systemFont(ofSize: 9), color: PDFColor.secondary, after: 2)
            }
            let metrics = ResultMetricsFormatter.lines(for: result, language: language)
            if !metrics.isEmpty {
                page.pairs(metrics.map { ($0.label, $0.value) }, font: .systemFont(ofSize: 10))
            }
            if !result.notes.isEmpty {
                page.text(result.notes, font: .systemFont(ofSize: 10), after: 4)
            }
            if !result.series.isEmpty {
                page.chart(result.series)
            }
            for filename in result.attachments {
                if let url = try? AttachmentStore.directory.appendingPathComponent(filename),
                   let image = UIImage(contentsOfFile: url.path) {
                    page.image(image, maxHeight: 220)
                }
            }
            page.space(10)
        }
        page.rule()
    }

    private func drawSignature(_ page: inout PageWriter) {
        let qrSide: CGFloat = 132
        page.ensureSpace(qrSide + 60)
        page.heading(L10nKey.reportSignature.text(in: language))
        let top = page.y
        if let payload = content.qrPayload, let qr = Self.qrImage(payload) {
            qr.draw(in: CGRect(x: Self.pageSize.width - Self.margin - qrSide, y: top, width: qrSide, height: qrSide))
        }
        let textWidth = Self.pageSize.width - 2 * Self.margin - qrSide - 16
        page.text(content.signatureStatus, font: .boldSystemFont(ofSize: 11), width: textWidth, after: 4)
        page.text("\(L10nKey.verifyFingerprint.text(in: language)): \(bundle.envelope.keyFingerprint)", font: .monospacedSystemFont(ofSize: 9, weight: .regular), width: textWidth, after: 4)
        page.text("SHA-256: \(bundle.envelope.sha256)", font: .monospacedSystemFont(ofSize: 7, weight: .regular), color: PDFColor.secondary, width: textWidth, after: 6)
        page.text(L10nKey.reportVerifyHint.text(in: language), font: .systemFont(ofSize: 9), width: textWidth, after: 4)
        page.y = max(page.y, top + qrSide + 12)
        page.rule()
    }

    // MARK: Helpers

    static func color(for outcome: TestOutcome) -> UIColor {
        switch outcome {
        case .pass: return .systemGreen
        case .attention: return .systemOrange
        case .fail: return .systemRed
        case .skipped, .notApplicable, .unavailable: return .systemGray
        }
    }

    /// The envelope as a QR code, medium error correction, drawn crisp at any size.
    static func qrImage(_ payload: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let cgImage = CIContext().createCGImage(output, from: output.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

/// Fixed colors: paper is always white, whatever the phone's appearance.
private enum PDFColor {
    static let text = UIColor.black
    static let secondary = UIColor.darkGray
    static let rule = UIColor.lightGray
}

/// Lays text and drawings down the page and starts a new page when the next block won't fit.
private struct PageWriter {
    let context: UIGraphicsPDFRendererContext
    let language: AppLanguage
    let reportID: String
    var y: CGFloat = 0
    private var pageNumber = 0

    private let margin: CGFloat = 48
    private var width: CGFloat { ReportPDFRenderer.pageSize.width - 2 * margin }
    private var bottom: CGFloat { ReportPDFRenderer.pageSize.height - margin - 16 }

    init(context: UIGraphicsPDFRendererContext, language: AppLanguage, reportID: String) {
        self.context = context
        self.language = language
        self.reportID = reportID
    }

    mutating func begin() {
        context.beginPage()
        pageNumber += 1
        y = margin
        let footer = "FoldCheck · \(reportID.prefix(8)) · \(L10nKey.reportPage.text(in: language, pageNumber))"
        (footer as NSString).draw(
            at: CGPoint(x: margin, y: ReportPDFRenderer.pageSize.height - margin + 8),
            withAttributes: [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: PDFColor.secondary]
        )
    }

    mutating func ensureSpace(_ height: CGFloat) {
        if y + height > bottom { begin() }
    }

    mutating func space(_ height: CGFloat) {
        y += height
    }

    mutating func text(_ string: String, font: UIFont, color: UIColor = PDFColor.text, width: CGFloat? = nil, after: CGFloat = 8) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let width = width ?? self.width
        let height = ceil((string as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes, context: nil
        ).height)
        ensureSpace(height)
        (string as NSString).draw(
            with: CGRect(x: margin, y: y, width: width, height: height),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes, context: nil
        )
        y += height + after
    }

    mutating func heading(_ string: String) {
        ensureSpace(40)
        text(string, font: .boldSystemFont(ofSize: 13), after: 6)
    }

    mutating func titleWithBadge(_ title: String, badge: String, color: UIColor) {
        ensureSpace(24)
        let badgeAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 10), .foregroundColor: color]
        let badgeSize = (badge as NSString).size(withAttributes: badgeAttributes)
        (badge as NSString).draw(at: CGPoint(x: margin + width - badgeSize.width, y: y + 1), withAttributes: badgeAttributes)
        text(title, font: .boldSystemFont(ofSize: 11), width: width - badgeSize.width - 12, after: 2)
    }

    /// Label–value rows in two columns.
    mutating func pairs(_ rows: [(String, String)], font: UIFont = .systemFont(ofSize: 10)) {
        let labelWidth = width * 0.4
        for (label, value) in rows {
            let lineHeight = ceil(font.lineHeight) + 3
            ensureSpace(lineHeight)
            (label as NSString).draw(
                in: CGRect(x: margin, y: y, width: labelWidth - 8, height: lineHeight),
                withAttributes: [.font: font, .foregroundColor: PDFColor.secondary]
            )
            (value as NSString).draw(
                in: CGRect(x: margin + labelWidth, y: y, width: width - labelWidth, height: lineHeight),
                withAttributes: [.font: font, .foregroundColor: PDFColor.text]
            )
            y += lineHeight
        }
        y += 4
    }

    mutating func rule() {
        ensureSpace(12)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: y + 4))
        path.addLine(to: CGPoint(x: margin + width, y: y + 4))
        PDFColor.rule.setStroke()
        path.lineWidth = 0.5
        path.stroke()
        y += 12
    }

    /// Hinge angle over time, 0–180°, one line per segment (sweep 1, sweep 2, hold).
    mutating func chart(_ points: [TestSeriesPoint]) {
        let height: CGFloat = 110
        ensureSpace(height + 8)
        let frame = CGRect(x: margin, y: y, width: width, height: height)
        PDFColor.rule.setStroke()
        UIBezierPath(rect: frame).stroke()
        let maxT = max(points.map(\.t).max() ?? 1, 0.001)
        let colors: [UIColor] = [.systemBlue, .systemGreen, .systemOrange]
        for segment in Set(points.map(\.segment)).sorted() {
            let path = UIBezierPath()
            for (index, point) in points.filter({ $0.segment == segment }).enumerated() {
                let location = CGPoint(
                    x: frame.minX + frame.width * point.t / maxT,
                    y: frame.maxY - frame.height * min(max(point.value, 0), 180) / 180
                )
                if index == 0 { path.move(to: location) } else { path.addLine(to: location) }
            }
            colors[segment % colors.count].setStroke()
            path.lineWidth = 1.2
            path.stroke()
        }
        for (label, value) in [("180°", 180.0), ("90°", 90.0), ("0°", 0.0)] {
            (label as NSString).draw(
                at: CGPoint(x: frame.maxX + 3, y: frame.maxY - frame.height * value / 180 - 5),
                withAttributes: [.font: UIFont.systemFont(ofSize: 7), .foregroundColor: PDFColor.secondary]
            )
        }
        y += height + 8
    }

    mutating func image(_ image: UIImage, maxHeight: CGFloat) {
        let scale = min(width / image.size.width, maxHeight / image.size.height, 1)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        ensureSpace(size.height + 8)
        image.draw(in: CGRect(origin: CGPoint(x: margin, y: y), size: size))
        y += size.height + 8
    }
}
