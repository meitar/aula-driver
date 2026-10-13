import Foundation
import IOKit.hid

public enum KnobEvent: Sendable, Equatable {
    case volumeUp
    case volumeDown
    case mute
    case playPause
    case unknown(UInt32)
}

public final class KnobEventMonitor: @unchecked Sendable {
    public static let shared = KnobEventMonitor()

    private var hidManager: IOHIDManager?
    public var onKnobAction: ((KnobEvent) -> Void)?
    public private(set) var rotationCount: Int = 0
    public private(set) var clickCount: Int = 0
    public private(set) var isMonitoring = false

    private init() {}

    public func startMonitoring() {
        guard !isMonitoring else { return }

        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.hidManager = manager

        let matching: [[String: Any]] = [
            [
                kIOHIDVendorIDKey: AulaConstants.wiredVendorID,
                kIOHIDProductIDKey: AulaConstants.wiredProductID,
                kIOHIDDeviceUsagePageKey: 0x0C // Consumer Control
            ],
            [
                kIOHIDVendorIDKey: AulaConstants.dongleVendorID,
                kIOHIDProductIDKey: AulaConstants.dongleProductID,
                kIOHIDDeviceUsagePageKey: 0x0C
            ]
        ]

        IOHIDManagerSetDeviceMatchingMultiple(manager, matching as CFArray)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputValueCallback(manager, { context, result, _, value in
            guard result == kIOReturnSuccess, let context else { return }
            let monitor = Unmanaged<KnobEventMonitor>.fromOpaque(context).takeUnretainedValue()
            let element = IOHIDValueGetElement(value)
            let usagePage = IOHIDElementGetUsagePage(element)
            let usage = IOHIDElementGetUsage(element)
            let intVal = IOHIDValueGetIntegerValue(value)

            // Only trigger on Consumer Control page (0x0C) and active actuation (intVal > 0)
            guard usagePage == 0x0C, intVal > 0 else { return }

            let event: KnobEvent
            switch usage {
            case 0xE9:
                event = .volumeUp
                monitor.rotationCount += 1
            case 0xEA:
                event = .volumeDown
                monitor.rotationCount += 1
            case 0xE2:
                event = .mute
                monitor.clickCount += 1
            case 0xCD:
                event = .playPause
                monitor.clickCount += 1
            default:
                event = .unknown(usage)
            }

            DispatchQueue.main.async {
                monitor.onKnobAction?(event)
            }
        }, context)

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        _ = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        isMonitoring = true
    }

    public func stopMonitoring() {
        guard isMonitoring, let hidManager else { return }
        IOHIDManagerUnscheduleFromRunLoop(hidManager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
        self.hidManager = nil
        isMonitoring = false
    }
}
