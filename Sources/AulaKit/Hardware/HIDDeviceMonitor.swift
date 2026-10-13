import Foundation
import IOKit.hid

public final class HIDDeviceMonitor {
    public var onDevicesChanged: (@Sendable () -> Void)?

    private var manager: IOHIDManager?

    public init() {}

    public func start() {
        guard manager == nil else { return }

        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = manager

        let matching: [[String: Any]] = [
            [
                kIOHIDVendorIDKey: AulaConstants.wiredVendorID,
                kIOHIDProductIDKey: AulaConstants.wiredProductID
            ],
            [
                kIOHIDVendorIDKey: AulaConstants.dongleVendorID,
                kIOHIDProductIDKey: AulaConstants.dongleProductID
            ]
        ]

        IOHIDManagerSetDeviceMatchingMultiple(manager, matching as CFArray)

        let context = Unmanaged.passUnretained(self).toOpaque()

        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, _ in
            guard let context else { return }
            let monitor = Unmanaged<HIDDeviceMonitor>.fromOpaque(context).takeUnretainedValue()
            monitor.onDevicesChanged?()
        }, context)

        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, _ in
            guard let context else { return }
            let monitor = Unmanaged<HIDDeviceMonitor>.fromOpaque(context).takeUnretainedValue()
            monitor.onDevicesChanged?()
        }, context)

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        _ = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    public func stop() {
        guard let manager else { return }
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = nil
    }

    deinit {
        stop()
    }
}
