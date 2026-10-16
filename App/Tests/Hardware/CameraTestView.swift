import SwiftUI
import AVFoundation
import FoldKit
import FoldL10n
import TestsKit

/// T5: opens each camera in turn. The user points it at something, taps Capture, and says
/// whether the picture looks right. Only brightness and sharpness numbers are kept; no image
/// is stored. No cameras (the simulator) is Unavailable; camera access off is Skipped.
struct CameraTestView: View {
    let initialFoldState: FoldState
    let onFinish: (TestResult) -> Void
    let onCancel: () -> Void

    @Environment(\.appLanguage) private var language
    @State private var source = CameraFrameSource()
    @State private var session = CameraTestSession(cameras: [])
    @State private var phase: Phase = .starting

    private enum Phase: Equatable {
        case starting
        case denied
        case preview(CameraInfo)
        case confirm(CameraInfo, FrameStats)
    }

    var body: some View {
        Group {
            switch phase {
            case .starting:
                TestStepScreen(systemImage: "camera.fill", title: L10nKey.camStarting.text(in: language), onCancel: cancel) {
                    ProgressView()
                } actions: {
                    EmptyView()
                }
            case .denied:
                PermissionDeniedScreen(
                    systemImage: "camera.fill",
                    reason: L10nKey.camDenied.text(in: language),
                    onSkip: { finishSkipped(reason: L10nKey.camDenied.text(in: language)) },
                    onCancel: cancel
                )
            case .preview(let camera):
                TestStepScreen(
                    step: step(for: camera),
                    systemImage: "camera.fill",
                    title: camera.name,
                    message: L10nKey.camInstruction.text(in: language),
                    onCancel: cancel
                ) {
                    CameraPreview(session: source.session)
                        .aspectRatio(3 / 4, contentMode: .fit)
                        .frame(maxHeight: 360)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } actions: {
                    StepButton(title: L10nKey.camCapture.text(in: language)) { capture(camera) }
                        .accessibilityIdentifier("cameras.capture")
                }
            case .confirm(let camera, let stats):
                TestStepScreen(
                    step: step(for: camera),
                    systemImage: "camera.fill",
                    title: camera.name,
                    message: L10nKey.camQuestion.text(in: language),
                    onCancel: cancel
                ) {
                    CameraPreview(session: source.session)
                        .aspectRatio(3 / 4, contentMode: .fit)
                        .frame(maxHeight: 360)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } actions: {
                    StepButton(title: L10nKey.camLooksWrong.text(in: language), prominent: false) {
                        record(.looksWrong(stats), for: camera)
                    }
                    .accessibilityIdentifier("cameras.looksWrong")
                    StepButton(title: L10nKey.camLooksRight.text(in: language)) {
                        record(.looksRight(stats), for: camera)
                    }
                    .accessibilityIdentifier("cameras.looksRight")
                }
            }
        }
        .task { await begin() }
        .onDisappear { source.stop() }
    }

    private func step(for camera: CameraInfo) -> (current: Int, total: Int) {
        ((session.cameras.firstIndex(of: camera) ?? 0) + 1, session.cameras.count)
    }

    private func begin() async {
        let cameras = CameraFrameSource.discoverCameras()
        guard !cameras.isEmpty else {
            finish(with: CameraTestSession(cameras: []), notes: L10nKey.camNoCameras.text(in: language))
            return
        }
        guard await CameraFrameSource.requestAccess() else {
            phase = .denied
            return
        }
        session = CameraTestSession(cameras: cameras)
        await openCurrentCamera()
    }

    private func openCurrentCamera() async {
        guard let camera = session.currentCamera else {
            finish(with: session, notes: notes())
            return
        }
        phase = .starting
        if await source.start(cameraID: camera.id) {
            phase = .preview(camera)
        } else {
            record(.notAvailableNow, for: camera)
        }
    }

    private func capture(_ camera: CameraInfo) {
        guard let frame = source.latestFrame(),
              let stats = FrameAnalysis.stats(gray: frame.gray, width: frame.width, height: frame.height) else {
            record(.noFrame, for: camera)
            return
        }
        phase = .confirm(camera, stats)
    }

    private func record(_ check: CameraCheck, for camera: CameraInfo) {
        session.record(check, for: camera)
        source.stop()
        Task { await openCurrentCamera() }
    }

    private func notes() -> String {
        func names(_ matches: (CameraCheck) -> Bool) -> [String] {
            session.cameras.filter { session.checks[$0.id].map(matches) == true }.map(\.name)
        }
        var lines: [String] = []
        let noFrame = names { $0 == .noFrame }
        if !noFrame.isEmpty { lines.append(L10nKey.camNoteNoFrame.text(in: language, noFrame.listed(in: language))) }
        let wrong = names { if case .looksWrong = $0 { return true } else { return false } }
        if !wrong.isEmpty { lines.append(L10nKey.camNoteLooksWrong.text(in: language, wrong.listed(in: language))) }
        let unavailable = names { $0 == .notAvailableNow }
        if !unavailable.isEmpty { lines.append(L10nKey.camNoteNotAvailable.text(in: language, unavailable.listed(in: language))) }
        return lines.joined(separator: "\n")
    }

    private func finish(with session: CameraTestSession, notes: String) {
        source.stop()
        onFinish(session.result(notes: notes))
    }

    private func finishSkipped(reason: String) {
        onFinish(TestResult(id: .cameras, outcome: .skipped, notes: reason))
    }

    private func cancel() {
        source.stop()
        onCancel()
    }
}

// MARK: - Camera access

/// Runs one camera at a time and keeps the latest frame's luma plane, downsampled to about
/// 160 px wide. Capture work happens on a private queue; the frame is read under a lock.
final class CameraFrameSource: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    struct Frame {
        let gray: [UInt8]
        let width: Int
        let height: Int
    }

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "foldcheck.camera")
    private let lock = NSLock()
    private var frame: Frame?
    private var frameIndex = 0

    static func discoverCameras() -> [CameraInfo] {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera],
            mediaType: .video,
            position: .unspecified
        )
        return discovery.devices.map { device in
            let position: CameraInfo.Position
            switch device.position {
            case .back: position = .back
            case .front: position = .front
            default: position = .unspecified
            }
            return CameraInfo(id: device.uniqueID, name: device.localizedName, position: position)
        }
    }

    static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    /// Opens the camera. False when it can't be used now (e.g. it belongs to the hidden display).
    func start(cameraID: String) async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                continuation.resume(returning: configure(cameraID: cameraID))
            }
        }
    }

    private func configure(cameraID: String) -> Bool {
        lock.withLock { frame = nil }
        if session.isRunning { session.stopRunning() }
        session.beginConfiguration()
        session.inputs.forEach(session.removeInput)
        session.outputs.forEach(session.removeOutput)
        let ready = addInputAndOutput(cameraID: cameraID)
        session.commitConfiguration()
        guard ready else { return false }
        session.startRunning()
        return session.isRunning
    }

    private func addInputAndOutput(cameraID: String) -> Bool {
        guard let device = AVCaptureDevice(uniqueID: cameraID),
              device.isConnected, !device.isSuspended,
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            return false
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { return false }
        session.addOutput(output)
        session.sessionPreset = session.canSetSessionPreset(.vga640x480) ? .vga640x480 : .high
        return true
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func latestFrame() -> Frame? {
        lock.withLock { frame }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frameIndex += 1
        // Every 5th frame is plenty for a snapshot taken on demand.
        guard frameIndex % 5 == 1, let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        CVPixelBufferLockBaseAddress(pixels, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixels, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddressOfPlane(pixels, 0) else { return }
        let width = CVPixelBufferGetWidthOfPlane(pixels, 0)
        let height = CVPixelBufferGetHeightOfPlane(pixels, 0)
        let rowBytes = CVPixelBufferGetBytesPerRowOfPlane(pixels, 0)
        let step = max(1, width / 160)
        let outWidth = width / step
        let outHeight = height / step
        let luma = base.assumingMemoryBound(to: UInt8.self)
        var gray = [UInt8](repeating: 0, count: outWidth * outHeight)
        for y in 0..<outHeight {
            let row = luma + y * step * rowBytes
            for x in 0..<outWidth {
                gray[y * outWidth + x] = row[x * step]
            }
        }
        let frame = Frame(gray: gray, width: outWidth, height: outHeight)
        lock.withLock { self.frame = frame }
    }
}

/// Live preview of the running capture session.
private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
