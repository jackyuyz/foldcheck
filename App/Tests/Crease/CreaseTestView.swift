import SwiftUI
import PhotosUI
import UIKit
import FoldKit
import FoldL10n
import TestsKit

/// T3: a gray ramp and line pattern across the crease; the user rates visibility 1–5 at three
/// guided viewing angles and can import a photo taken with another device.
struct CreaseTestView: View {
    let initialFoldState: FoldState
    let onFinish: (TestResult) -> Void
    let onCancel: () -> Void

    @Environment(\.appLanguage) private var language
    @State private var session = CreaseVisibilitySession()
    @State private var foldState: FoldState
    @State private var display: DisplayKind?
    @State private var photoItem: PhotosPickerItem?
    @State private var photo: UIImage?

    init(initialFoldState: FoldState, onFinish: @escaping (TestResult) -> Void, onCancel: @escaping () -> Void) {
        self.initialFoldState = initialFoldState
        self.onFinish = onFinish
        self.onCancel = onCancel
        _foldState = State(initialValue: initialFoldState)
        _display = State(initialValue: DisplayKind(posture: initialFoldState.posture))
    }

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width > geometry.size.height
            ZStack(alignment: wide ? .leading : .bottom) {
                CreasePattern(crease: DisplaySpec.duoInner.crease ?? .init())
                    .accessibilityHidden(true)

                panel
                    .frame(maxWidth: wide ? geometry.size.width / 2 - 40 : .infinity)
                    .padding(wide ? 20 : 12)
            }
            .overlay(alignment: .topLeading) {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .frame(width: 36, height: 36)
                        .background(.regularMaterial, in: Circle())
                }
                .padding(.leading, 16)
                .padding(.top, 8)
                .accessibilityLabel(Text(verbatim: "Cancel"))
                .accessibilityIdentifier("test.cancel")
            }
        }
        .statusBarHidden()
        .observeFoldState($foldState)
        .modifier(DisplayChangePause(foldState: foldState) { newDisplay in
            display = newDisplay
            session = CreaseVisibilitySession()
            removePhoto()
        })
        .onChange(of: photoItem) { _, item in
            Task { await importPhoto(item) }
        }
    }

    // MARK: Panel

    private var panel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10nKey.creaseStep.text(in: language, session.currentIndex + 1, session.views.count).uppercased())
                .font(.caption.bold())
                .foregroundStyle(Color(red: 0.055, green: 0.478, blue: 0.271))
                .accessibilityIdentifier("crease.step")
            Text(L10nKey.creaseQuestion.text(in: language))
                .font(.title3.bold())
            Text(instruction(for: session.currentView))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ForEach(Array(CreaseVisibilitySession.ratingRange), id: \.self) { rating in
                    let selected = session.currentRating == rating
                    Button {
                        session.rate(rating, hingeAngle: foldState.angleDegrees)
                    } label: {
                        Text("\(rating)")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(selected ? Color.primary : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(selected ? Color(uiColor: .systemBackground) : Color.primary)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.5)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityIdentifier("crease.rating.\(rating)")
                }
            }
            Text(L10nKey.creaseScale.text(in: language))
                .font(.caption)
                .foregroundStyle(.secondary)

            if let angle = foldState.angleDegrees {
                Text(L10nKey.creaseHingeAngle.text(in: language, Int(angle.rounded())))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("crease.hingeAngle")
            }

            if session.isLastView {
                photoSection
            }

            HStack {
                if session.currentIndex > 0 {
                    Button(L10nKey.testBack.text(in: language)) {
                        session.goBack()
                    }
                    .accessibilityIdentifier("crease.back")
                }
                Spacer()
                Button {
                    if session.advance() {
                        finish()
                    }
                } label: {
                    Text(session.isLastView ? L10nKey.testFinish.text(in: language) : L10nKey.testNext.text(in: language))
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.055, green: 0.478, blue: 0.271))
                .disabled(!session.canAdvance)
                .accessibilityIdentifier("crease.next")
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let photo {
                HStack(spacing: 10) {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text(L10nKey.creasePhotoAttached.text(in: language))
                        .font(.subheadline)
                    Spacer()
                    Button(L10nKey.creasePhotoRemove.text(in: language), role: .destructive) {
                        removePhoto()
                    }
                    .font(.caption)
                }
            } else {
                let title = L10nKey.creasePhoto.text(in: language)
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(title, systemImage: "photo.badge.plus")
                        .font(.subheadline)
                }
                .accessibilityIdentifier("crease.photo")
                Text(L10nKey.creasePhotoTip.text(in: language))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func instruction(for view: CreaseViewingAngle) -> String {
        switch view {
        case .straightOn: return L10nKey.creaseView1.text(in: language)
        case .tiltedSideLight: return L10nKey.creaseView2.text(in: language)
        case .foldedNinety: return L10nKey.creaseView3.text(in: language)
        }
    }

    // MARK: Photo

    private func importPhoto(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let filename = try? AttachmentStore.saveDownscaledJPEG(image, prefix: "crease") else { return }
        removePhoto()
        photo = image
        session.attach(filename)
    }

    private func removePhoto() {
        for filename in session.attachments {
            AttachmentStore.delete(filename)
        }
        session.removeAttachments()
        photo = nil
        photoItem = nil
    }

    private func finish() {
        onFinish(session.result(display: display))
    }
}

// MARK: - Pattern

/// Gray ramp that peaks at the fold plus fine vertical lines: both make crease distortion
/// easier to see. Absolute colors, not adaptive.
private struct CreasePattern: View {
    let crease: DisplaySpec.Crease

    var body: some View {
        Canvas { context, size in
            let vertical = crease.axis == .vertical
            let length = vertical ? size.width : size.height
            let center = CGFloat(crease.position)
            let gradient = Gradient(stops: [
                .init(color: Color(white: 0.85), location: 0),
                .init(color: Color(white: 0.55), location: max(center - 0.02, 0)),
                .init(color: Color(white: 0.95), location: center),
                .init(color: Color(white: 0.55), location: min(center + 0.02, 1)),
                .init(color: Color(white: 0.85), location: 1),
            ])
            let rect = CGRect(origin: .zero, size: size)
            context.fill(
                Path(rect),
                with: .linearGradient(
                    gradient,
                    startPoint: .zero,
                    endPoint: vertical ? CGPoint(x: size.width, y: 0) : CGPoint(x: 0, y: size.height)
                )
            )
            var x: CGFloat = 0
            var lines = Path()
            while x < length {
                if vertical {
                    lines.addRect(CGRect(x: x, y: 0, width: 1, height: size.height))
                } else {
                    lines.addRect(CGRect(x: 0, y: x, width: size.width, height: 1))
                }
                x += 15
            }
            context.fill(lines, with: .color(.black.opacity(0.25)))
        }
        .ignoresSafeArea()
    }
}

// MARK: - Attachments

/// Imported photos live in Application Support/Reports/Attachments, downscaled to 1600 px.
enum AttachmentStore {
    static let maxPixelSize: CGFloat = 1600

    static var directory: URL {
        get throws {
            let base = try FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
            )
            let url = base.appendingPathComponent("Reports/Attachments", isDirectory: true)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }
    }

    static func saveDownscaledJPEG(_ image: UIImage, prefix: String) throws -> String {
        let scale = min(1, maxPixelSize / max(image.size.width * image.scale, image.size.height * image.scale))
        let target = CGSize(
            width: (image.size.width * image.scale * scale).rounded(),
            height: (image.size.height * image.scale * scale).rounded()
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        guard let data = resized.jpegData(compressionQuality: 0.85) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let filename = "\(prefix)-\(UUID().uuidString).jpg"
        try data.write(to: try directory.appendingPathComponent(filename), options: [.atomic, .completeFileProtection])
        return filename
    }

    static func delete(_ filename: String) {
        guard let url = try? directory.appendingPathComponent(filename) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
