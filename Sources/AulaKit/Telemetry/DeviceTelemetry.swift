import Foundation
import IOKit.hid
import CoreGraphics

public enum DeviceConnectionMode: String, Codable, Sendable {
    case wiredUSB = "Wired USB (0x0C45:0x800A)"
    case wireless24G = "2.4GHz Wireless (0x05AC:0x024F)"
    case disconnected = "Disconnected"
}

public struct DeviceTelemetrySnapshot: Sendable {
    public let timestamp: Date
    public let mode: DeviceConnectionMode
    public let vendorID: Int
    public let productID: Int
    public let vendorHex: String
    public let productHex: String
    public let productName: String
    public let manufacturer: String
    public let serialNumber: String?
    public let locationID: Int
    public let transport: String
    public let usbSpeed: String
    public let endpointCount: Int
    public let batteryPercent: Int?
    public let isCharging: Bool
    public let capsLockActive: Bool
    public let numLockActive: Bool
    public let scrollLockActive: Bool
    public let roundTripLatencyMs: Double

    public init(
        timestamp: Date = Date(),
        mode: DeviceConnectionMode,
        vendorID: Int,
        productID: Int,
        vendorHex: String,
        productHex: String,
        productName: String,
        manufacturer: String,
        serialNumber: String?,
        locationID: Int,
        transport: String,
        usbSpeed: String,
        endpointCount: Int,
        batteryPercent: Int?,
        isCharging: Bool,
        capsLockActive: Bool,
        numLockActive: Bool,
        scrollLockActive: Bool,
        roundTripLatencyMs: Double
    ) {
        self.timestamp = timestamp
        self.mode = mode
        self.vendorID = vendorID
        self.productID = productID
        self.vendorHex = vendorHex
        self.productHex = productHex
        self.productName = productName
        self.manufacturer = manufacturer
        self.serialNumber = serialNumber
        self.locationID = locationID
        self.transport = transport
        self.usbSpeed = usbSpeed
        self.endpointCount = endpointCount
        self.batteryPercent = batteryPercent
        self.isCharging = isCharging
        self.capsLockActive = capsLockActive
        self.numLockActive = numLockActive
        self.scrollLockActive = scrollLockActive
        self.roundTripLatencyMs = roundTripLatencyMs
    }
}

public enum DeviceTelemetryProvider {
    public static func capture() -> DeviceTelemetrySnapshot {
        let wiredEndpoints = AulaDevice.scanEndpoints()
        let wirelessEndpoints = WirelessAulaDevice.scanEndpoints()

        let mode: DeviceConnectionMode
        let endpoints: [HIDEndpointInfo]
        let vid: Int
        let pid: Int
        let name: String
        let transport: String

        if !wiredEndpoints.isEmpty {
            mode = .wiredUSB
            endpoints = wiredEndpoints
            vid = AulaConstants.wiredVendorID
            pid = AulaConstants.wiredProductID
            name = wiredEndpoints.first?.product ?? "AULA F108Pro"
            transport = wiredEndpoints.first?.transport ?? "USB"
        } else if !wirelessEndpoints.isEmpty {
            mode = .wireless24G
            endpoints = wirelessEndpoints
            vid = AulaConstants.dongleVendorID
            pid = AulaConstants.dongleProductID
            name = wirelessEndpoints.first?.product ?? "F108Pro Dongle"
            transport = wirelessEndpoints.first?.transport ?? "USB (Wireless Dongle)"
        } else {
            mode = .disconnected
            endpoints = []
            vid = 0
            pid = 0
            name = "None"
            transport = "None"
        }

        // Query battery if in wireless mode
        var battery: Int? = nil
        if mode == .wireless24G {
            battery = try? WirelessAulaDevice.connect().queryBattery()
        }

        // Lock key detection via CoreGraphics event source
        let capsLock = CGEventSource.keyState(.hidSystemState, key: 0x39) // CapsLock HID 0x39
        let numLock = CGEventSource.keyState(.hidSystemState, key: 0x53)  // NumLock HID 0x53
        let scrollLock = CGEventSource.keyState(.hidSystemState, key: 0x47) // ScrollLock HID 0x47

        // Benchmark latency if connected
        var latencyMs: Double = 0.0
        if mode == .wiredUSB {
            let start = DispatchTime.now()
            if let device = try? AulaDevice.connect() {
                // Send a lightweight clock sync or status exchange to measure roundtrip
                _ = try? device.syncClock()
                let elapsed = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
                latencyMs = Double(elapsed) / 1_000_000.0
            }
        }

        return DeviceTelemetrySnapshot(
            mode: mode,
            vendorID: vid,
            productID: pid,
            vendorHex: String(format: "0x%04X", vid),
            productHex: String(format: "0x%04X", pid),
            productName: name,
            manufacturer: mode == .wiredUSB ? "Dongguan Suoai Electronic Technology Co." : "Aula / Suoai",
            serialNumber: nil,
            locationID: 0,
            transport: transport,
            usbSpeed: "12 Mbps (USB Full Speed)",
            endpointCount: endpoints.count,
            batteryPercent: battery,
            isCharging: mode == .wiredUSB,
            capsLockActive: capsLock,
            numLockActive: numLock,
            scrollLockActive: scrollLock,
            roundTripLatencyMs: latencyMs
        )
    }
}
