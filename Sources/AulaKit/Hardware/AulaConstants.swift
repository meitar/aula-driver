import Foundation

public enum AulaConstants {
    // USB Device Identifiers
    public static let wiredVendorID = 0x0C45
    public static let wiredProductID = 0x800A
    public static let dongleVendorID = 0x05AC
    public static let dongleProductID = 0x024F

    // HID Usage Pages
    public static let wiredCommandUsagePage = 0xFF13     // Feature report configuration channel (64 bytes)
    public static let wiredRawUsagePage = 0xFF68         // High-speed LCD output report channel (4096 bytes)
    public static let wirelessCommandUsagePage = 0xFF59  // 2.4G wireless command endpoint
    public static let wirelessRawUsagePage = 0xFF60      // 2.4G wireless raw / battery query endpoint

    // Protocol Sizes & Timings
    public static let commandLength = 64
    public static let ackLength = 64
    public static let chunkLength = 4096
    public static let commandDelayMs: UInt32 = 35000 // 35 ms in microseconds

    // F108 Pro Smart TFT Screen Specifications
    public static let displayWidth = 240
    public static let displayHeight = 135
    public static let headerLength = 256
    public static let frameBytes = displayWidth * displayHeight * 2 // 64,800 bytes per frame (RGB565)
    public static let maxFrames = 255

    // Key Remapping & Macros
    public static let remapSlots = 144
    public static let remapSlotBytes = 4
    public static let remapTableLength = 576 // 144 slots * 4 bytes
    public static let maxMacros = 100
    public static let maxMacroTableBytes = 3584
}

public enum AulaError: LocalizedError {
    case deviceNotFound
    case endpointNotFound(String)
    case openFailed(String)
    case hidFailed(String, Int32)
    case imageLoadFailed(String)
    case imageTooLarge(String)
    case invalidSlot(Int)
    case timeout(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return "Aula F108 Pro keyboard was not found. Please connect via USB-C or 2.4G receiver."
        case .endpointNotFound(let endpoint):
            return "Required HID endpoint was not found: \(endpoint)."
        case .openFailed(let detail):
            return "Failed to open HID device: \(detail)."
        case .hidFailed(let op, let code):
            return "\(op) failed with IOReturn 0x\(String(UInt32(bitPattern: code), radix: 16))."
        case .imageLoadFailed(let detail):
            return "Failed to load image: \(detail)."
        case .imageTooLarge(let detail):
            return "Image payload too large: \(detail)."
        case .invalidSlot(let slot):
            return "Slot \(slot) is invalid (must be between 1 and 255)."
        case .timeout(let op):
            return "Operation timed out: \(op)."
        case .cancelled:
            return "Operation cancelled."
        }
    }
}

public struct HIDEndpointInfo: Identifiable, Hashable, Sendable {
    public let id: String
    public let vendorID: Int
    public let productID: Int
    public let usagePage: Int
    public let usage: Int
    public let maxInputReportSize: Int
    public let maxOutputReportSize: Int
    public let maxFeatureReportSize: Int
    public let product: String
    public let transport: String

    public init(
        id: String,
        vendorID: Int,
        productID: Int,
        usagePage: Int,
        usage: Int,
        maxInputReportSize: Int,
        maxOutputReportSize: Int,
        maxFeatureReportSize: Int,
        product: String,
        transport: String
    ) {
        self.id = id
        self.vendorID = vendorID
        self.productID = productID
        self.usagePage = usagePage
        self.usage = usage
        self.maxInputReportSize = maxInputReportSize
        self.maxOutputReportSize = maxOutputReportSize
        self.maxFeatureReportSize = maxFeatureReportSize
        self.product = product
        self.transport = transport
    }

    public var role: String {
        if vendorID == AulaConstants.dongleVendorID && productID == AulaConstants.dongleProductID {
            if usagePage == AulaConstants.wirelessCommandUsagePage { return "2.4G Command" }
            if usagePage == AulaConstants.wirelessRawUsagePage { return "2.4G Raw" }
        }
        if usagePage == AulaConstants.wiredCommandUsagePage { return "Configuration (Feature)" }
        if usagePage == AulaConstants.wiredRawUsagePage { return "LCD Stream (Output)" }
        if usagePage == 0x0001 && usage == 0x0006 { return "Standard Keyboard" }
        if usagePage == 0x000C { return "Consumer / Knob" }
        return "HID (0x\(String(usagePage, radix: 16)))"
    }

    public var summary: String {
        "\(role) [In: \(maxInputReportSize)B, Out: \(maxOutputReportSize)B, Feat: \(maxFeatureReportSize)B]"
    }
}
