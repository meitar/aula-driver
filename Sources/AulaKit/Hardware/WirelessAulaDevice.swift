import Foundation
import IOKit.hid

public final class WirelessAulaDevice {
    private let rawDevice: IOHIDDevice
    private let outputReportSize: Int
    private let featureReportSize: Int
    private var batteryPipe: BatteryInputPipe?

    private init(rawDevice: IOHIDDevice) throws {
        self.rawDevice = rawDevice
        self.outputReportSize = Self.intProperty(rawDevice, kIOHIDMaxOutputReportSizeKey)
        self.featureReportSize = Self.intProperty(rawDevice, kIOHIDMaxFeatureReportSizeKey)
        let result = IOHIDDeviceOpen(rawDevice, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            throw AulaError.openFailed("2.4G dongle raw endpoint (0xFF60), IOReturn 0x\(String(UInt32(result), radix: 16))")
        }
    }

    deinit {
        batteryPipe?.close()
        IOHIDDeviceClose(rawDevice, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    public static func connect() throws -> WirelessAulaDevice {
        let devices = matchingDongleDevices()
        if let raw = devices.first(where: { usagePage($0) == AulaConstants.wirelessRawUsagePage }) {
            return try WirelessAulaDevice(rawDevice: raw)
        }
        throw AulaError.endpointNotFound("2.4G wireless raw channel 0xFF60")
    }

    public static func scanEndpoints() -> [HIDEndpointInfo] {
        matchingDongleDevices().enumerated().map { index, device in
            let vendorID = intProperty(device, kIOHIDVendorIDKey)
            let productID = intProperty(device, kIOHIDProductIDKey)
            let page = usagePage(device)
            let usageVal = usage(device)
            return HIDEndpointInfo(
                id: "dongle-\(index)-\(page)-\(usageVal)",
                vendorID: vendorID,
                productID: productID,
                usagePage: page,
                usage: usageVal,
                maxInputReportSize: intProperty(device, kIOHIDMaxInputReportSizeKey),
                maxOutputReportSize: intProperty(device, kIOHIDMaxOutputReportSizeKey),
                maxFeatureReportSize: intProperty(device, kIOHIDMaxFeatureReportSizeKey),
                product: stringProperty(device, kIOHIDProductKey) ?? "F108Pro Dongle",
                transport: stringProperty(device, kIOHIDTransportKey) ?? "USB"
            )
        }.sorted {
            if $0.usagePage != $1.usagePage { return $0.usagePage < $1.usagePage }
            return $0.usage < $1.usage
        }
    }

    // MARK: - Battery Query
    public func queryBattery() throws -> Int? {
        let pipe = BatteryInputPipe(device: rawDevice)
        batteryPipe = pipe
        pipe.start()

        let lengths = [
            min(max(outputReportSize, 32), 64),
            outputReportSize >= 33 ? 33 : outputReportSize
        ].filter { $0 > 0 }

        for length in lengths {
            try sendBatteryQuery(includeReportID: false, length: length)
            if let percent = pipe.waitForPercent(timeout: 0.25) {
                return percent
            }
            try sendBatteryQuery(includeReportID: true, length: length)
            if let percent = pipe.waitForPercent(timeout: 0.25) {
                return percent
            }
        }

        return pipe.percent
    }

    private func sendBatteryQuery(includeReportID: Bool, length: Int) throws {
        var payload = [UInt8](repeating: 0, count: max(length, 32))
        if includeReportID {
            payload[0] = 0x00
            payload[1] = 0x20
            payload[2] = 0x01
        } else {
            payload[0] = 0x20
            payload[1] = 0x01
        }
        let checksumIndex = includeReportID ? 32 : 31
        applyChecksum(to: &payload, checksumIndex: checksumIndex)
        try sendRawReport(payload)
    }

    // MARK: - Wireless RGB Lighting
    public func applyRGB(
        mode: Int,
        brightness: Int,
        speed: Int,
        direction: Int,
        colorful: Bool,
        color: Int
    ) throws {
        // Step 1: Commit report
        var commit = [UInt8](repeating: 0, count: 32)
        commit[0] = 0x0F
        applyChecksum(to: &commit, checksumIndex: 31)
        try sendRawReport(commit)
        Thread.sleep(forTimeInterval: 0.05)

        // Step 2: LED report
        var report = [UInt8](repeating: 0, count: 32)
        report[0] = 0x05
        report[1] = 0x10
        report[2] = 0x00
        report[3] = UInt8(clamping: mode)
        if mode != 0 {
            report[4] = UInt8((color >> 16) & 0xFF)
            report[5] = UInt8((color >> 8) & 0xFF)
            report[6] = UInt8(color & 0xFF)
            report[11] = colorful ? 1 : 0
            report[12] = UInt8(clamping: brightness)
            report[13] = UInt8(clamping: speed)
            report[14] = UInt8(clamping: direction)
        }
        report[17] = 0xAA
        report[18] = 0x55
        applyChecksum(to: &report, checksumIndex: 31)
        try sendRawReport(report)
    }

    // MARK: - Wireless Performance
    public func applyPerformance(level: Int, sleepTime: Int) throws {
        var report = [UInt8](repeating: 0, count: 32)
        report[0] = 0x07
        report[1] = 0x10
        report[4] = 0x01
        report[5] = 0x01
        report[6] = 0x01
        report[7] = 0x01
        report[8] = 0x01 // fnSwitch
        report[9] = UInt8(clamping: sleepTime)
        report[11] = UInt8(clamping: level)
        report[17] = 0xAA
        report[18] = 0x55
        applyChecksum(to: &report, checksumIndex: 31)
        try sendRawReport(report)
    }

    public func setGameMode(enabled: Bool, level: Int, sleepTime: Int) throws {
        var report = [UInt8](repeating: 0, count: 32)
        report[0] = 0x07
        report[1] = 0x10
        report[4] = 0x01
        report[5] = 0x01
        report[6] = 0x01
        report[7] = 0x01
        report[8] = 0x01
        report[9] = UInt8(clamping: sleepTime)
        report[11] = UInt8(clamping: level)
        let val: UInt8 = enabled ? 1 : 0
        report[12] = val // gameMode
        report[13] = val // disableAltTab
        report[14] = val // disableAltF4
        report[15] = val // disableWin
        report[17] = 0xAA
        report[18] = 0x55
        applyChecksum(to: &report, checksumIndex: 31)
        try sendRawReport(report)
    }

    private func applyChecksum(to bytes: inout [UInt8], checksumIndex: Int) {
        guard bytes.indices.contains(checksumIndex) else { return }
        bytes[checksumIndex] = 0
        let sum = bytes.reduce(UInt8(0)) { partial, byte in
            partial &+ byte
        }
        bytes[checksumIndex] = sum
    }

    private func sendRawReport(_ report: [UInt8]) throws {
        let result = report.withUnsafeBufferPointer { pointer in
            IOHIDDeviceSetReport(rawDevice, kIOHIDReportTypeOutput, 0, pointer.baseAddress!, report.count)
        }
        guard result == kIOReturnSuccess else {
            throw AulaError.hidFailed("2.4G SET_REPORT", Int32(result))
        }
    }

    private static func matchingDongleDevices() -> [IOHIDDevice] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [String: Any] = [
            kIOHIDVendorIDKey: AulaConstants.dongleVendorID,
            kIOHIDProductIDKey: AulaConstants.dongleProductID
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        _ = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        defer { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }

        guard let deviceSet = IOHIDManagerCopyDevices(manager) else { return [] }
        let count = CFSetGetCount(deviceSet)
        var rawValues = [UnsafeRawPointer?](repeating: nil, count: count)
        CFSetGetValues(deviceSet, &rawValues)
        return rawValues.compactMap { value in
            guard let value else { return nil }
            return Unmanaged<IOHIDDevice>.fromOpaque(value).retain().takeRetainedValue()
        }
    }

    private static func intProperty(_ device: IOHIDDevice, _ key: String) -> Int {
        guard let value = IOHIDDeviceGetProperty(device, key as CFString) else { return 0 }
        if CFGetTypeID(value) == CFNumberGetTypeID() {
            return (value as! NSNumber).intValue
        }
        return 0
    }

    private static func stringProperty(_ device: IOHIDDevice, _ key: String) -> String? {
        guard let value = IOHIDDeviceGetProperty(device, key as CFString) else { return nil }
        return value as? String
    }

    private static func usagePage(_ device: IOHIDDevice) -> Int {
        let primary = intProperty(device, kIOHIDPrimaryUsagePageKey)
        return primary != 0 ? primary : intProperty(device, kIOHIDDeviceUsagePageKey)
    }

    private static func usage(_ device: IOHIDDevice) -> Int {
        let primary = intProperty(device, kIOHIDPrimaryUsageKey)
        return primary != 0 ? primary : intProperty(device, kIOHIDDeviceUsageKey)
    }
}

private final class BatteryInputPipe {
    private let device: IOHIDDevice
    private var inputBuffer: [UInt8]
    private(set) var percent: Int?
    private var started = false

    init(device: IOHIDDevice) {
        self.device = device
        self.inputBuffer = [UInt8](repeating: 0, count: 64)
    }

    func start() {
        guard !started else { return }
        started = true

        let context = Unmanaged.passUnretained(self).toOpaque()
        inputBuffer.withUnsafeMutableBufferPointer { pointer in
            IOHIDDeviceRegisterInputReportCallback(
                device,
                pointer.baseAddress!,
                pointer.count,
                { context, result, _, _, _, report, reportLength in
                    guard result == kIOReturnSuccess, reportLength > 0, let context else { return }
                    let pipe = Unmanaged<BatteryInputPipe>.fromOpaque(context).takeUnretainedValue()
                    let data = Array(UnsafeBufferPointer(start: report, count: reportLength))
                    pipe.parseBattery(data)
                },
                context
            )
        }
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    }

    func waitForPercent(timeout: TimeInterval) -> Int? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let percent { return percent }
            CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0.02, true)
        }
        return percent
    }

    private func parseBattery(_ bytes: [UInt8]) {
        for index in 0..<(bytes.count - 1) {
            if bytes[index] == 0x20, bytes.indices.contains(index + 2) {
                let val = Int(bytes[index + 2])
                if (0...100).contains(val) {
                    self.percent = val
                    return
                }
            }
        }
    }

    func close() {
        guard started else { return }
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        started = false
    }
}
