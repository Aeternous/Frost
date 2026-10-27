// Frost — a frosted glass effect on the MacBook screen as the lid closes.
import AppKit
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let sensor = LidSensor()
    private let hotkeys = Hotkeys()
    private var tracker = TiltTracker()
    private var overlay: GlassOverlay?
    private var mirror: ScreenMirror?

    private var status: NSStatusItem!
    private let angleItem = NSMenuItem(title: "Lid angle: —", action: nil, keyEquivalent: "")
    private var permissionItem: NSMenuItem!
    private var enabledItem: NSMenuItem!
    private var previewItem: NSMenuItem!

    private var enabled = true
    private var previewing = false
    private var previewTimeout: DispatchWorkItem?

    private var closed = 0.0            // smoothed degrees closed from the resting angle
    private var visibility = 0.0        // 1 while the lid moves, fading to 0 once it's still
    private var lastActive = -Double.infinity

    private let deadZone = 6.0          // degrees of closing ignored, so small adjustments do nothing
    private let fadeInSpan = 8.0        // degrees past the dead zone over which the effect fades in
    private let blurSpan = 50.0         // degrees past the dead zone to reach full blur
    private let fullTilt = 60.0         // degrees closed at which the glass is fully tipped

    func applicationDidFinishLaunching(_ note: Notification) {
        buildMenu()
        hotkeys.register(kVK_ANSI_E) { [weak self] in self?.toggleEnabled() }
        hotkeys.register(kVK_ANSI_R) { [weak self] in self?.resetRestingAngle() }
        hotkeys.register(kVK_ANSI_P) { [weak self] in self?.togglePreview() }
        hotkeys.register(kVK_ANSI_Q) { NSApp.terminate(nil) }

        guard sensor.available else {
            angleItem.title = "No lid angle sensor found"
            return
        }
        if !ScreenMirror.permitted { CGRequestScreenCaptureAccess() }

        setUpOverlay()
        NotificationCenter.default.addObserver(self, selector: #selector(setUpOverlay),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
    }

    private func buildMenu() {
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "rectangle.portrait.on.rectangle.portrait.angled",
                                       accessibilityDescription: "Frost")
            ?? NSImage(systemSymbolName: "laptopcomputer", accessibilityDescription: "Frost")

        permissionItem = NSMenuItem(title: "Allow Screen Recording…", action: #selector(openPermission), keyEquivalent: "")
        enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "e")
        enabledItem.state = .on
        previewItem = NSMenuItem(title: "Preview Effect", action: #selector(togglePreview), keyEquivalent: "p")

        let menu = NSMenu()
        for item in [angleItem, permissionItem!, .separator(), enabledItem!,
                     NSMenuItem(title: "Reset Resting Angle", action: #selector(resetRestingAngle), keyEquivalent: "r"),
                     previewItem!, .separator(),
                     NSMenuItem(title: "Quit Frost", action: #selector(NSApp.terminate), keyEquivalent: "q")] {
            item.target = item.action == #selector(NSApp.terminate) ? NSApp : self
            // Shown as ⌃⌥⌘ + letter, matching the global shortcuts.
            item.keyEquivalentModifierMask = [.control, .option, .command]
            menu.addItem(item)
        }
        status.menu = menu
    }

    /// Covers the built-in display, and rebuilds when displays change.
    @objc private func setUpOverlay() {
        overlay?.window.orderOut(nil)
        mirror?.stop()
        overlay = nil
        mirror = nil
        for screen in NSScreen.screens {
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
                  CGDisplayIsBuiltin(id) != 0 else { continue }
            let newOverlay = GlassOverlay(screen: screen)
            let newMirror = ScreenMirror(displayID: id)
            newMirror.onFrame = { [weak newOverlay] in newOverlay?.show(frame: $0) }
            overlay = newOverlay
            mirror = newMirror
        }
    }

    /// Runs 60 times a second: reads the lid and updates the glass.
    private func tick() {
        guard let angle = sensor.angle() else { return }
        angleItem.title = String(format: "Lid angle: %.0f°", angle)
        permissionItem.isHidden = ScreenMirror.permitted

        let now = ProcessInfo.processInfo.systemUptime
        let lid = tracker.update(angle: angle, now: now)
        let closedBy = previewing ? deadZone + fadeInSpan + 20 : lid.closedBy
        let moving = previewing || (enabled && lid.moving)

        // Capture only runs around lid movement. It starts on the first degree of motion,
        // before the dead zone is passed, so frames are ready when the effect appears.
        if moving {
            lastActive = now
            mirror?.start()
        } else if now - lastActive > 3, visibility < 0.01 {
            mirror?.stop()
            overlay?.clearFrame()
        }

        closed += (closedBy - closed) * 0.35
        // Quick fade in while moving, gentler fade back to normal once still.
        visibility += ((moving ? 1 : 0) - visibility) * (moving ? 0.3 : 0.08)
        let fadeIn = clamp((closed - deadZone) / fadeInSpan)
        overlay?.update(tilt: clamp(closed / fullTilt),
                        blur: clamp((closed - deadZone) / blurSpan),
                        opacity: visibility * fadeIn)
    }

    private func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }

    @objc private func toggleEnabled() {
        enabled.toggle()
        enabledItem.state = enabled ? .on : .off
    }

    @objc private func resetRestingAngle() { tracker.reset() }

    /// Shows the effect for 5 seconds; it ends by itself because the blur makes the menu hard to find.
    @objc private func togglePreview() {
        previewTimeout?.cancel()
        previewing.toggle()
        previewItem.state = previewing ? .on : .off
        guard previewing else { return }
        let timeout = DispatchWorkItem { [weak self] in self?.togglePreview() }
        previewTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: timeout)
    }

    @objc private func openPermission() {
        CGRequestScreenCaptureAccess()
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
