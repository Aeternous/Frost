import ScreenCaptureKit

/// Streams live frames of one display, leaving out Frost's own window.
final class ScreenMirror: NSObject, SCStreamOutput {
    let displayID: CGDirectDisplayID
    var onFrame: ((CVPixelBuffer) -> Void)?

    private var stream: SCStream?
    private var starting = false
    private var wanted = false
    private var lastFailure = -Double.infinity

    init(displayID: CGDirectDisplayID) {
        self.displayID = displayID
    }

    static var permitted: Bool { CGPreflightScreenCaptureAccess() }

    func start() {
        wanted = true
        // macOS's permission check can be wrong, so always try, but wait 5 seconds after a failure.
        let now = ProcessInfo.processInfo.systemUptime
        guard stream == nil, !starting, now - lastFailure > 5 else { return }
        starting = true
        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { [weak self] content, _ in
            DispatchQueue.main.async { self?.begin(with: content) }
        }
    }

    func stop() {
        wanted = false
        stream?.stopCapture()
        stream = nil
    }

    private func begin(with content: SCShareableContent?) {
        guard wanted, let content, let display = content.displays.first(where: { $0.displayID == displayID }) else {
            fail()
            return
        }
        let me = content.applications.filter { $0.processID == getpid() }
        let filter = SCContentFilter(display: display, excludingApplications: me, exceptingWindows: [])

        // Point resolution (half the Retina pixels) is plenty, since the image is always blurred.
        let config = SCStreamConfiguration()
        config.width = display.width
        config.height = display.height
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true

        let s = SCStream(filter: filter, configuration: config, delegate: nil)
        guard (try? s.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)) != nil else {
            fail()
            return
        }
        s.startCapture { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }
                if error != nil { return self.fail() }
                self.starting = false
                if self.wanted { self.stream = s } else { s.stopCapture() }
            }
        }
    }

    private func fail() {
        starting = false
        lastFailure = ProcessInfo.processInfo.systemUptime
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        // Only complete frames carry new pixels; idle frames mean nothing changed.
        guard type == .screen,
              let info = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false)
                as? [[SCStreamFrameInfo: Any]],
              let status = info.first?[.status] as? Int, SCFrameStatus(rawValue: status) == .complete,
              let pixels = CMSampleBufferGetImageBuffer(buffer)
        else { return }
        onFrame?(pixels)
    }
}
