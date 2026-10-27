import IOKit.hid

/// Reads the lid hinge angle, in degrees, from the MacBook's built-in lid angle sensor.
final class LidSensor {
    private let manager: IOHIDManager   // must stay alive as long as the device is used
    private var device: IOHIDDevice?

    init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let match: [String: Any] = [
            kIOHIDVendorIDKey: 0x05AC,          // Apple
            kIOHIDProductIDKey: 0x8104,         // sensor hub
            kIOHIDPrimaryUsagePageKey: 0x0020,  // sensor
            kIOHIDPrimaryUsageKey: 0x008A,      // orientation (lid angle)
        ]
        IOHIDManagerSetDeviceMatching(manager, match as CFDictionary)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        // Keep the first matching device that actually returns an angle.
        let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []
        for candidate in devices where IOHIDDeviceOpen(candidate, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess {
            device = candidate
            if angle() != nil { return }
        }
        device = nil
    }

    var available: Bool { device != nil }

    func angle() -> Double? {
        guard let device else { return nil }
        var report = [UInt8](repeating: 0, count: 8)
        var length = CFIndex(report.count)
        guard IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &report, &length) == kIOReturnSuccess,
              length >= 3 else { return nil }
        return Double(UInt16(report[2]) << 8 | UInt16(report[1]))  // bytes 1–2, little-endian
    }
}
