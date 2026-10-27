import AppKit

/// A click-through window over the built-in display. As the lid closes, the screen is blurred in
/// place under a glossy glass pane shaped like the display (rounded top corners and the camera
/// notch). The pane tips toward the viewer with the lid: its bottom edge draws in a little.
final class GlassOverlay {
    let window: NSWindow
    private let size: CGSize
    private let notch: CGRect?                   // camera cutout, if the display has one

    private let frosted = CALayer()              // the blurred screen
    private let shadow = CALayer()               // soft shadow under the pane
    private let body = CAShapeLayer()            // the pane: a faint milky lift
    private let sheen = CAGradientLayer()        // glow fading down from the top edge
    private let sheenMask = CAShapeLayer()
    private let edge = CAShapeLayer()            // bright top edge, following the notch
    private let sides = CAShapeLayer()           // faint side and bottom edges

    private let maxBlur = 45.0                   // blur radius in points at full strength
    private let tipInset: CGFloat = 18           // how far the bottom edge draws in at full tilt
    private let cornerRadius: CGFloat = 10       // the display's rounded top corners
    private let notchRadius: CGFloat = 8         // rounded bottom corners of the notch

    // sRGB keeps the milky wash looking as light as it should; in linear light dark screens turn grey.
    private let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
    private var latest: CIImage?
    private var newFrame = false
    private var renderedBlur = -1.0

    init(screen: NSScreen) {
        size = screen.frame.size
        // The notch is the gap between the usable strips to its left and right.
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let height = screen.safeAreaInsets.top
            notch = CGRect(x: left.maxX - screen.frame.minX, y: size.height - height,
                           width: right.minX - left.maxX, height: height)
        } else {
            notch = nil
        }

        window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        // Never get in the way: clicks pass through, and it's hidden from screen sharing.
        window.ignoresMouseEvents = true
        window.sharingType = .none
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        let root = NSView(frame: NSRect(origin: .zero, size: size))
        root.wantsLayer = true
        window.contentView = root
        let bounds = root.bounds
        let white = { (alpha: CGFloat) in NSColor(white: 1, alpha: alpha).cgColor }

        frosted.contentsGravity = .resize

        shadow.shadowColor = NSColor.black.cgColor
        shadow.shadowOpacity = 0.55
        shadow.shadowRadius = 12
        shadow.shadowOffset = CGSize(width: 0, height: -3)

        body.fillColor = white(0.05)

        sheen.colors = [white(0.16), white(0.04), white(0)]
        sheen.locations = [0, 0.25, 1]
        sheen.startPoint = CGPoint(x: 0.5, y: 1)   // top of the screen
        sheen.compositingFilter = "screenBlendMode"
        sheen.mask = sheenMask

        sides.fillColor = nil
        sides.strokeColor = white(0.35)
        sides.lineWidth = 1

        edge.fillColor = nil
        edge.strokeColor = white(0.85)
        edge.lineWidth = 2
        edge.lineCap = .round
        edge.shadowColor = NSColor.white.cgColor   // soft glow around the edge line
        edge.shadowOpacity = 0.6
        edge.shadowRadius = 4
        edge.shadowOffset = .zero

        for layer in [frosted, shadow, body, sheen, sheenMask, sides, edge] { layer.frame = bounds }
        for layer in [frosted, shadow, body, sheen, sides, edge] { root.layer!.addSublayer(layer) }

        update(tilt: 0, blur: 0, opacity: 0)
    }

    func show(frame pixels: CVPixelBuffer) {
        latest = CIImage(cvPixelBuffer: pixels)
        newFrame = true
    }

    /// Forgets the last frame so a later fade-in never shows an old screen.
    func clearFrame() {
        latest = nil
        frosted.contents = nil
    }

    /// tilt, blur and opacity all run from 0 to 1.
    func update(tilt: Double, blur: Double, opacity: Double) {
        // Nothing to show without a captured frame; treat a nearly finished fade as gone.
        let opacity = latest == nil || opacity < 0.001 ? 0 : opacity
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        window.alphaValue = opacity

        // Pane outline: the display's top edge, then a bottom edge that draws in with the tilt.
        let w = size.width, h = size.height, inset = tipInset * tilt
        let top = topEdge()
        let pane = CGMutablePath()
        pane.addPath(top)
        pane.addLine(to: CGPoint(x: w - inset, y: 0))
        pane.addLine(to: CGPoint(x: inset, y: 0))
        pane.closeSubpath()
        body.path = pane
        sheenMask.path = pane
        shadow.shadowPath = pane
        edge.path = top

        let rest = CGMutablePath()
        rest.addLines(between: [CGPoint(x: w, y: h - cornerRadius), CGPoint(x: w - inset, y: 0),
                                CGPoint(x: inset, y: 0), CGPoint(x: 0, y: h - cornerRadius)])
        sides.path = rest

        // The glass catches more light the further it tips.
        sheen.endPoint = CGPoint(x: 0.5, y: 0.7 - 0.2 * tilt)
        sheen.opacity = Float(0.5 + 0.5 * tilt)
        edge.opacity = Float(0.6 + 0.4 * tilt)

        let radius = blur * maxBlur
        if opacity > 0, newFrame || abs(radius - renderedBlur) > 0.5 { render(blur: radius) }
        CATransaction.commit()

        if opacity > 0 { window.orderFrontRegardless() } else { window.orderOut(nil) }
    }

    /// The display's top outline, left to right: rounded corners, dipping around the notch.
    private func topEdge() -> CGPath {
        let w = size.width, h = size.height, r = cornerRadius
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: h - r))
        path.addArc(tangent1End: CGPoint(x: 0, y: h), tangent2End: CGPoint(x: r, y: h), radius: r)
        if let n = notch {
            path.addLine(to: CGPoint(x: n.minX, y: h))
            path.addArc(tangent1End: CGPoint(x: n.minX, y: n.minY), tangent2End: CGPoint(x: n.midX, y: n.minY),
                        radius: notchRadius)
            path.addArc(tangent1End: CGPoint(x: n.maxX, y: n.minY), tangent2End: CGPoint(x: n.maxX, y: h),
                        radius: notchRadius)
            path.addLine(to: CGPoint(x: n.maxX, y: h))
        }
        path.addArc(tangent1End: CGPoint(x: w, y: h), tangent2End: CGPoint(x: w, y: h - r), radius: r)
        return path
    }

    /// Blurs the latest frame on the GPU at half size, with a light milky wash that grows with the blur.
    private func render(blur radius: Double) {
        guard let image = latest else { return }
        let half = image.transformed(by: CGAffineTransform(scaleX: 0.5, y: 0.5))
        let milk = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: 0.02 + 0.06 * radius / maxBlur))
        let blurred = half
            .clampedToExtent()                       // stops the blur pulling black in at the borders
            .applyingGaussianBlur(sigma: radius * 0.25 * image.extent.width / size.width)
            .applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 0.95, kCIInputBrightnessKey: 0.01])
        frosted.contents = context.createCGImage(milk.composited(over: blurred).cropped(to: half.extent),
                                                 from: half.extent)
        newFrame = false
        renderedBlur = radius
    }
}
