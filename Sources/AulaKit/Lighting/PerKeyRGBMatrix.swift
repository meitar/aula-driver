import Foundation

public struct KeyRGBColor: Hashable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public static let off = KeyRGBColor(red: 0, green: 0, blue: 0)
    public static let white = KeyRGBColor(red: 255, green: 255, blue: 255)
    public static let redColor = KeyRGBColor(red: 255, green: 0, blue: 0)
    public static let greenColor = KeyRGBColor(red: 0, green: 255, blue: 0)
    public static let blueColor = KeyRGBColor(red: 0, green: 0, blue: 255)
}

public struct PerKeyRGBMatrix: Sendable {
    public private(set) var colors: [Int: KeyRGBColor] = [:] // key_index -> RGB

    public init(colors: [Int: KeyRGBColor] = [:]) {
        self.colors = colors
    }

    public mutating func setColor(_ color: KeyRGBColor, for keyIndex: Int) {
        colors[keyIndex] = color
    }

    public mutating func clearAll() {
        colors.removeAll()
    }

    public func buildPayload() -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: AulaConstants.remapTableLength) // 576 bytes

        for (keyIndex, color) in colors where keyIndex >= 0 && keyIndex < 144 {
            let offset = keyIndex * 4
            guard offset + 3 < 574 else { continue }
            buffer[offset + 0] = UInt8(clamping: keyIndex)
            buffer[offset + 1] = color.red
            buffer[offset + 2] = color.green
            buffer[offset + 3] = color.blue
        }

        // Trailer: 0x55AA in little-endian = 0xAA 0x55 at the final 2 bytes
        buffer[574] = 0xAA
        buffer[575] = 0x55
        return buffer
    }
}
