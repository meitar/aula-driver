import Foundation
import IOKit.hid

public struct DisplayUploadProgress: Sendable {
    public let sentChunks: Int
    public let totalChunks: Int

    public init(sentChunks: Int, totalChunks: Int) {
        self.sentChunks = sentChunks
        self.totalChunks = totalChunks
    }

    public var fraction: Double {
        guard totalChunks > 0 else { return 0 }
        return Double(sentChunks) / Double(totalChunks)
    }

    public var percent: Int {
        Int(fraction * 100)
    }
}

public final class AulaDevice {
    private let commandDevice: IOHIDDevice
    private let rawDevice: IOHIDDevice?
    private var rawInputPipe: RawInputPipe?

    private init(commandDevice: IOHIDDevice, rawDevice: IOHIDDevice?) throws {
        self.commandDevice = commandDevice
        self.rawDevice = rawDevice

        try Self.open(commandDevice, label: "command endpoint (0xFF13)")
        if let rawDevice {
            try Self.open(rawDevice, label: "raw display endpoint (0xFF68)")
            self.rawInputPipe = RawInputPipe(device: rawDevice)
        }
    }

    deinit {
        rawInputPipe?.close()
        if let rawDevice {
            IOHIDDeviceClose(rawDevice, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        IOHIDDeviceClose(commandDevice, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    public static func connect() throws -> AulaDevice {
        let devices = matchingHIDDevices()
        guard !devices.isEmpty else {
            throw AulaError.deviceNotFound
        }

        let command = devices.first { usagePage($0) == AulaConstants.wiredCommandUsagePage }
            ?? devices.first { maxFeatureReportSize($0) >= AulaConstants.commandLength }
        guard let command else {
            throw AulaError.endpointNotFound("wired configuration channel 0xFF13")
        }

        let raw = devices.first { usagePage($0) == AulaConstants.wiredRawUsagePage }
            ?? devices.first { maxOutputReportSize($0) >= AulaConstants.chunkLength }

        return try AulaDevice(commandDevice: command, rawDevice: raw)
    }

    public static func scanEndpoints() -> [HIDEndpointInfo] {
        matchingHIDDevices().enumerated().map { index, device in
            let vendorID = intProperty(device, kIOHIDVendorIDKey)
            let productID = intProperty(device, kIOHIDProductIDKey)
            let page = usagePage(device)
            let usageVal = usage(device)
            let product = stringProperty(device, kIOHIDProductKey) ?? "AULA F108Pro"
            let transport = stringProperty(device, kIOHIDTransportKey) ?? "USB"
            return HIDEndpointInfo(
                id: "wired-\(index)-\(page)-\(usageVal)",
                vendorID: vendorID,
                productID: productID,
                usagePage: page,
                usage: usageVal,
                maxInputReportSize: maxInputReportSize(device),
                maxOutputReportSize: maxOutputReportSize(device),
                maxFeatureReportSize: maxFeatureReportSize(device),
                product: product,
                transport: transport
            )
        }.sorted {
            if $0.usagePage != $1.usagePage { return $0.usagePage < $1.usagePage }
            return $0.usage < $1.usage
        }
    }

    // MARK: - Clock Synchronization
    public func syncClock(date: Date = Date(), calendar: Calendar = .current) throws {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .weekday], from: date)
        let yearMod = (parts.year ?? 2026) % 2000
        let month = parts.month ?? 1
        let day = parts.day ?? 1
        let hour = parts.hour ?? 0
        let minute = parts.minute ?? 0
        let second = parts.second ?? 0
        let weekday = max((parts.weekday ?? 1) - 1, 0) // 0=Sun..6=Sat

        // 1. Begin transaction
        try commandExchange(Self.packet(0x04, 0x18))

        // 2. Clock init (0x04 0x28, byte 8 = 0x01)
        var prepare = Self.packet(0x04, 0x28)
        prepare[8] = 0x01
        try commandExchange(prepare)

        // 3. Payload with timestamp and trailer 0xAA 0x55
        var timePacket = [UInt8](repeating: 0, count: AulaConstants.commandLength)
        timePacket[0] = 0x00
        timePacket[1] = 0x01 // profile
        timePacket[2] = 0x5A // magic
        timePacket[3] = UInt8(clamping: yearMod)
        timePacket[4] = UInt8(clamping: month)
        timePacket[5] = UInt8(clamping: day)
        timePacket[6] = UInt8(clamping: hour)
        timePacket[7] = UInt8(clamping: minute)
        timePacket[8] = UInt8(clamping: second)
        timePacket[10] = UInt8(clamping: weekday)
        timePacket[62] = 0xAA // Little-endian 0x55AA
        timePacket[63] = 0x55
        try commandExchange(timePacket)

        // 4. Apply
        try commandExchange(Self.packet(0x04, 0x02))
    }

    // MARK: - Screen Image / GIF Upload
    public func uploadDisplayStream(
        _ stream: Data,
        slot: Int = 1,
        progress: @escaping @Sendable (DisplayUploadProgress) -> Void
    ) throws {
        guard (1...255).contains(slot) else {
            throw AulaError.invalidSlot(slot)
        }
        guard let rawDevice else {
            throw AulaError.endpointNotFound("wired display channel 0xFF68 (Interface 2)")
        }

        let chunkCount = stream.count / AulaConstants.chunkLength
        guard chunkCount <= 0xFFFF else {
            throw AulaError.imageTooLarge("\(chunkCount) chunks exceeds UInt16 metadata limit")
        }

        // 1. Begin transaction on interface 3
        try commandExchange(Self.packet(0x04, 0x18))

        // 2. Header packet 0x04 0x72 with slot and total page count
        var metadata = Self.packet(0x04, 0x72)
        metadata[2] = UInt8(slot)
        metadata[8] = UInt8(chunkCount & 0xFF)
        metadata[9] = UInt8((chunkCount >> 8) & 0xFF)
        try commandExchange(metadata)

        // 3. Start ACK monitoring on interface 2
        rawInputPipe?.start()
        defer { rawInputPipe?.close() }
        _ = rawInputPipe?.waitForAck(timeout: 0.08)

        // 4. Send 4096-byte Output reports
        for chunkIndex in 0..<chunkCount {
            let offset = chunkIndex * AulaConstants.chunkLength
            let chunk = stream[offset..<(offset + AulaConstants.chunkLength)]
            try Self.setReport(
                device: rawDevice,
                type: kIOHIDReportTypeOutput,
                reportID: 0,
                bytes: Array(chunk),
                operation: "display page \(chunkIndex + 1)/\(chunkCount)"
            )
            _ = rawInputPipe?.waitForAck(timeout: 0.12)
            progress(DisplayUploadProgress(sentChunks: chunkIndex + 1, totalChunks: chunkCount))
        }

        // 5. Apply
        try commandExchange(Self.packet(0x04, 0x02))
    }

    // MARK: - RGB Lighting
    public func applyRGB(
        mode: Int,
        brightness: Int,
        speed: Int,
        direction: Int,
        colorful: Bool,
        color: Int
    ) throws {
        let normMode = min(max(mode, 0), 25)
        let normBrightness = min(max(brightness, 0), 5)
        let normSpeed = min(max(speed, 1), 5)
        let normDirection = min(max(direction, 0), 3)
        let normColor = min(max(color, 0), 0xFFFFFF)

        // Step 1: Lighting init 04 13 (byte[8] = 0x01)
        var initPacket = Self.packet(0x04, 0x13)
        initPacket[8] = 0x01
        try commandExchange(initPacket)
        usleep(AulaConstants.commandDelayMs)

        // Step 2: Payload (64 bytes)
        var payload = [UInt8](repeating: 0, count: AulaConstants.commandLength)
        payload[0] = UInt8(normMode)
        if normMode != 0 {
            payload[1] = UInt8((normColor >> 16) & 0xFF)    // R
            payload[2] = UInt8((normColor >> 8) & 0xFF)     // G
            payload[3] = UInt8(normColor & 0xFF)            // B
            payload[8] = colorful ? 1 : 0
            payload[9] = UInt8(normBrightness)
            payload[10] = UInt8(normSpeed)
            payload[11] = UInt8(normDirection)
        }
        // Standard Sonix delimiter at bytes 62 and 63
        payload[62] = 0x55
        payload[63] = 0xAA
        // Keep bytes 14 and 15 set as well in case of firmware variant check
        payload[14] = 0xAA
        payload[15] = 0x55
        try commandExchange(payload)
        usleep(AulaConstants.commandDelayMs)

        // Step 3: Apply / Save (04 02)
        try commandExchange(Self.packet(0x04, 0x02))
        usleep(AulaConstants.commandDelayMs)
    }

    // MARK: - Macro Synchronization
    public func uploadMacros(_ macros: [KeyboardMacro]) throws {
        let serialized = try MacroEngine.serializeMacros(macros)
        let packetCount = serialized.count / AulaConstants.commandLength

        // 1. Begin transaction
        try commandExchange(Self.packet(0x04, 0x18))

        // 2. Macro data header (0x04 0x15, byte[8] = packet count)
        var header = Self.packet(0x04, 0x15)
        header[8] = UInt8(packetCount)
        try commandExchange(header)

        // 3. Send data packets (64 bytes each)
        for i in 0..<packetCount {
            let start = i * AulaConstants.commandLength
            let end = start + AulaConstants.commandLength
            let packet = Array(serialized[start..<end])
            if i == packetCount - 1 {
                // Readback on final packet
                try commandExchange(packet)
            } else {
                try Self.setReport(
                    device: commandDevice,
                    type: kIOHIDReportTypeFeature,
                    reportID: 0,
                    bytes: packet,
                    operation: "macro chunk \(i + 1)/\(packetCount)"
                )
                usleep(AulaConstants.commandDelayMs)
            }
        }

        // 4. Apply
        try commandExchange(Self.packet(0x04, 0x02))

        // 5. Finalize
        let finalPacket = Self.packet(0x04, 0xF0)
        try? sendFeatureNoReadback(finalPacket)
    }

    // MARK: - Per-Key RGB Matrix (576 bytes)
    public func applyPerKeyRGB(buffer: [UInt8]) throws {
        guard buffer.count == 576 else {
            throw AulaError.hidFailed("Per-key RGB buffer must be exactly 576 bytes", 0)
        }

        try commandExchange(Self.packet(0x04, 0x18))

        var initPacket = Self.packet(0x04, 0x23)
        initPacket[8] = 0x09
        try commandExchange(initPacket)

        // Send 9 packets of 64 bytes
        for packetIndex in 0..<9 {
            let start = packetIndex * 64
            let chunk = Array(buffer[start..<(start + 64)])
            try Self.setReport(
                device: commandDevice,
                type: kIOHIDReportTypeFeature,
                reportID: 0,
                bytes: chunk,
                operation: "per-key RGB chunk \(packetIndex + 1)"
            )
            usleep(AulaConstants.commandDelayMs)
        }

        try commandExchange(Self.packet(0x04, 0x02))
        _ = try? sendFeatureNoReadback(Self.packet(0x04, 0xF0))
    }

    // MARK: - Key Remapping (Normal or FN Layer)
    public func applyKeyRemap(layer: KeyRemapLayer, table: [UInt8]) throws {
        guard table.count == AulaConstants.remapTableLength else {
            throw AulaError.hidFailed("Remap table must be exactly 576 bytes", 0)
        }

        // 1. Begin transaction
        try commandExchange(Self.packet(0x04, 0x18))

        // 2. Remap init (0x04 0x11 for normal, 0x04 0x27 for FN, byte[8] = 0x09)
        var initPacket = Self.packet(0x04, layer.commandByte)
        initPacket[8] = 0x09
        try commandExchange(initPacket)

        // 3. Send 576 bytes across 9 packets (pure payload chunks without readback)
        for packetIndex in 0..<9 {
            let start = packetIndex * 64
            let chunk = Array(table[start..<(start + 64)])
            try Self.setReport(
                device: commandDevice,
                type: kIOHIDReportTypeFeature,
                reportID: 0,
                bytes: chunk,
                operation: "remap chunk \(packetIndex + 1)"
            )
            usleep(AulaConstants.commandDelayMs)
        }

        // 4. Apply
        try commandExchange(Self.packet(0x04, 0x02))

        // 5. Finalize
        _ = try? sendFeatureNoReadback(Self.packet(0x04, 0xF0))
    }

    // MARK: - Performance & System Settings
    public func applyPerformance(responseLevel: Int, sleepTime: Int) throws {
        var report = [UInt8](repeating: 0, count: AulaConstants.commandLength)
        report[0] = 0x07
        report[1] = 0x10
        report[4] = 0x01
        report[5] = 0x01
        report[6] = 0x01
        report[7] = 0x01
        report[8] = 0x01 // fnSwitch
        report[9] = UInt8(clamping: sleepTime)
        report[11] = UInt8(clamping: responseLevel)
        report[17] = 0xAA
        report[18] = 0x55
        // Checksum at byte 31
        var sum: UInt8 = 0
        for i in 0..<31 { sum = sum &+ report[i] }
        report[31] = sum

        try sendFeatureNoReadback(report)
    }

    // MARK: - Factory Reset
    public func factoryReset(progress: @escaping @Sendable (String) -> Void) throws {
        progress("Clearing display memory...")
        try commandExchange(Self.packet(0x04, 0x19))
        var clearSlots = Self.packet(0x04, 0x15)
        clearSlots[8] = 0x08
        try commandExchange(clearSlots)
        try sendZeroPages(8)
        try commandExchange(Self.packet(0x04, 0x02))

        progress("Resetting keymaps...")
        try commandExchange(Self.packet(0x04, 0x18))
        var keymap = Self.packet(0x04, 0x11)
        keymap[8] = 0x09
        try commandExchange(keymap)
        try sendZeroPages(9)
        try commandExchange(Self.packet(0x04, 0x02))
        _ = try? sendFeatureNoReadback(Self.packet(0x04, 0xF0))

        progress("Resetting lighting...")
        try commandExchange(Self.packet(0x04, 0x18))
        var lighting = Self.packet(0x04, 0x27)
        lighting[8] = 0x09
        try commandExchange(lighting)
        try sendZeroPages(9)
        try commandExchange(Self.packet(0x04, 0x02))
        _ = try? sendFeatureNoReadback(Self.packet(0x04, 0xF0))

        progress("Restoring factory defaults...")
        try commandExchange(Self.packet(0x04, 0x18))
        var resetHeader = Self.packet(0x04, 0x13)
        resetHeader[8] = 0x01
        try commandExchange(resetHeader)

        var resetPayload = [UInt8](repeating: 0, count: AulaConstants.commandLength)
        resetPayload[0] = 0x0B
        resetPayload[1] = 0xFF
        resetPayload[8] = 0x01
        resetPayload[9] = 0x05
        resetPayload[10] = 0x03
        resetPayload[14] = 0xAA
        resetPayload[15] = 0x55
        try commandExchange(resetPayload)
        try commandExchange(Self.packet(0x04, 0x02))
        _ = try? sendFeatureNoReadback(Self.packet(0x04, 0xF0))
        progress("Factory reset complete.")
    }

    // MARK: - Internal Transport Helpers
    private func sendFeatureNoReadback(_ packet: [UInt8]) throws {
        var payload = packet
        if payload.count < AulaConstants.commandLength {
            payload += [UInt8](repeating: 0, count: AulaConstants.commandLength - payload.count)
        }
        try Self.setReport(
            device: commandDevice,
            type: kIOHIDReportTypeFeature,
            reportID: 0,
            bytes: payload,
            operation: "SET_REPORT (No Readback)"
        )
    }

    private func commandExchange(_ packet: [UInt8]) throws {
        var payload = packet
        if payload.count < AulaConstants.commandLength {
            payload += [UInt8](repeating: 0, count: AulaConstants.commandLength - payload.count)
        }

        try Self.setReport(
            device: commandDevice,
            type: kIOHIDReportTypeFeature,
            reportID: 0,
            bytes: payload,
            operation: "SET_REPORT"
        )

        // Allow keyboard MCU time to process the feature report
        usleep(AulaConstants.commandDelayMs)

        var response = [UInt8](repeating: 0, count: AulaConstants.commandLength)
        var responseLength = response.count
        var result: IOReturn = kIOReturnError

        // Retry loop for GET_REPORT in case device MCU is temporarily busy
        for _ in 0..<5 {
            responseLength = response.count
            result = response.withUnsafeMutableBufferPointer { pointer in
                IOHIDDeviceGetReport(
                    commandDevice,
                    kIOHIDReportTypeFeature,
                    0,
                    pointer.baseAddress!,
                    &responseLength
                )
            }
            if result == kIOReturnSuccess {
                break
            }
            usleep(25_000)
        }

        guard result == kIOReturnSuccess else {
            throw AulaError.hidFailed("GET_REPORT (ACK)", Int32(result))
        }

        usleep(AulaConstants.commandDelayMs)
    }

    private func sendZeroPages(_ count: Int) throws {
        guard count > 0 else { return }
        let zero = [UInt8](repeating: 0, count: AulaConstants.commandLength)
        for _ in 0..<count {
            try Self.setReport(
                device: commandDevice,
                type: kIOHIDReportTypeFeature,
                reportID: 0,
                bytes: zero,
                operation: "zero page"
            )
            usleep(AulaConstants.commandDelayMs)
        }
    }

    private static func packet(_ first: UInt8, _ second: UInt8) -> [UInt8] {
        var data = [UInt8](repeating: 0, count: AulaConstants.commandLength)
        data[0] = first
        data[1] = second
        return data
    }

    private static func open(_ device: IOHIDDevice, label: String) throws {
        let result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            throw AulaError.openFailed("\(label), IOReturn 0x\(String(UInt32(result), radix: 16))")
        }
    }

    private static func setReport(
        device: IOHIDDevice,
        type: IOHIDReportType,
        reportID: CFIndex,
        bytes: [UInt8],
        operation: String
    ) throws {
        let result = bytes.withUnsafeBufferPointer { pointer in
            IOHIDDeviceSetReport(device, type, reportID, pointer.baseAddress!, bytes.count)
        }
        guard result == kIOReturnSuccess else {
            throw AulaError.hidFailed(operation, Int32(result))
        }
    }

    private static func matchingHIDDevices() -> [IOHIDDevice] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [String: Any] = [
            kIOHIDVendorIDKey: AulaConstants.wiredVendorID,
            kIOHIDProductIDKey: AulaConstants.wiredProductID
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

    private static func maxInputReportSize(_ device: IOHIDDevice) -> Int {
        intProperty(device, kIOHIDMaxInputReportSizeKey)
    }

    private static func maxOutputReportSize(_ device: IOHIDDevice) -> Int {
        intProperty(device, kIOHIDMaxOutputReportSizeKey)
    }

    private static func maxFeatureReportSize(_ device: IOHIDDevice) -> Int {
        intProperty(device, kIOHIDMaxFeatureReportSizeKey)
    }
}

public enum KeyRemapLayer: String, Codable, Sendable {
    case normal
    case fn

    public var commandByte: UInt8 {
        switch self {
        case .normal: return 0x11
        case .fn: return 0x27
        }
    }
}

// MARK: - Asynchronous Raw Input Pipe for LCD ACKs
private final class RawInputPipe: @unchecked Sendable {
    private let device: IOHIDDevice
    private var inputBuffer: [UInt8]
    private let queue = DispatchQueue(label: "com.aulakit.rawinput", qos: .userInteractive)
    private let condition = NSCondition()
    private var ackCounter = 0
    private var started = false

    init(device: IOHIDDevice) {
        self.device = device
        self.inputBuffer = [UInt8](repeating: 0, count: max(512, AulaConstants.ackLength))
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
                { context, result, _, _, _, _, reportLength in
                    guard result == kIOReturnSuccess, reportLength > 0, let context else { return }
                    let pipe = Unmanaged<RawInputPipe>.fromOpaque(context).takeUnretainedValue()
                    pipe.condition.lock()
                    pipe.ackCounter += 1
                    pipe.condition.broadcast()
                    pipe.condition.unlock()
                },
                context
            )
        }
        IOHIDDeviceSetDispatchQueue(device, queue)
    }

    func waitForAck(timeout: TimeInterval) -> Bool {
        condition.lock()
        defer { condition.unlock() }

        let baseline = ackCounter
        let deadline = Date().addingTimeInterval(timeout)

        while ackCounter <= baseline {
            if !condition.wait(until: deadline) {
                return ackCounter > baseline
            }
        }
        return true
    }

    func close() {
        guard started else { return }
        inputBuffer.withUnsafeMutableBufferPointer { pointer in
            IOHIDDeviceRegisterInputReportCallback(
                device,
                pointer.baseAddress!,
                pointer.count,
                nil,
                nil
            )
        }
        started = false
    }
}
