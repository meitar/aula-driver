import Foundation

public struct KeyDefinition: Identifiable, Hashable, Sendable {
    public let code: UInt8      // USB HID Scancode (Usage Page 0x07)
    public let name: String     // Display name (e.g. "Esc", "A")
    public let keyIndex: Int    // Board key index (1..123)
    public let row: Int         // Visual row (0..5)
    public let col: Double      // Visual col offset (0..22)
    public let width: Double    // Key width in standard key units (1.0 = standard, 2.25 = Return, etc.)
    public let fnDisabled: Bool // Whether firmware disables FN-layer remapping

    public var id: Int { keyIndex }

    public init(
        code: UInt8,
        name: String,
        keyIndex: Int,
        row: Int,
        col: Double,
        width: Double = 1.0,
        fnDisabled: Bool = false
    ) {
        self.code = code
        self.name = name
        self.keyIndex = keyIndex
        self.row = row
        self.col = col
        self.width = width
        self.fnDisabled = fnDisabled
    }
}

public enum KeyCatalog {
    public static let allKeys: [KeyDefinition] = [
        // Row 0: Function Row
        KeyDefinition(code: 0x29, name: "Esc", keyIndex: 1, row: 0, col: 0.0),
        KeyDefinition(code: 0x3A, name: "F1", keyIndex: 2, row: 0, col: 2.0),
        KeyDefinition(code: 0x3B, name: "F2", keyIndex: 3, row: 0, col: 3.0),
        KeyDefinition(code: 0x3C, name: "F3", keyIndex: 4, row: 0, col: 4.0),
        KeyDefinition(code: 0x3D, name: "F4", keyIndex: 5, row: 0, col: 5.0),
        KeyDefinition(code: 0x3E, name: "F5", keyIndex: 6, row: 0, col: 6.5),
        KeyDefinition(code: 0x3F, name: "F6", keyIndex: 7, row: 0, col: 7.5),
        KeyDefinition(code: 0x40, name: "F7", keyIndex: 8, row: 0, col: 8.5),
        KeyDefinition(code: 0x41, name: "F8", keyIndex: 9, row: 0, col: 9.5),
        KeyDefinition(code: 0x42, name: "F9", keyIndex: 10, row: 0, col: 11.0),
        KeyDefinition(code: 0x43, name: "F10", keyIndex: 11, row: 0, col: 12.0),
        KeyDefinition(code: 0x44, name: "F11", keyIndex: 12, row: 0, col: 13.0),
        KeyDefinition(code: 0x45, name: "F12", keyIndex: 13, row: 0, col: 14.0),
        KeyDefinition(code: 0x46, name: "PrtSc", keyIndex: 112, row: 0, col: 15.5),
        KeyDefinition(code: 0x47, name: "ScrLk", keyIndex: 113, row: 0, col: 16.5),
        KeyDefinition(code: 0x48, name: "Pause", keyIndex: 115, row: 0, col: 17.5),
        // 4 extra keys above numpad
        KeyDefinition(code: 0x00, name: "Calc", keyIndex: 114, row: 0, col: 19.0),
        KeyDefinition(code: 0x00, name: "Mute", keyIndex: 111, row: 0, col: 20.0),
        KeyDefinition(code: 0x00, name: "Vol-", keyIndex: 110, row: 0, col: 21.0),
        KeyDefinition(code: 0x00, name: "Vol+", keyIndex: 109, row: 0, col: 22.0),

        // Row 1: Number Row
        KeyDefinition(code: 0x35, name: "`~", keyIndex: 19, row: 1, col: 0.0),
        KeyDefinition(code: 0x1E, name: "1!", keyIndex: 20, row: 1, col: 1.0),
        KeyDefinition(code: 0x1F, name: "2@", keyIndex: 21, row: 1, col: 2.0),
        KeyDefinition(code: 0x20, name: "3#", keyIndex: 22, row: 1, col: 3.0),
        KeyDefinition(code: 0x21, name: "4$", keyIndex: 23, row: 1, col: 4.0),
        KeyDefinition(code: 0x22, name: "5%", keyIndex: 24, row: 1, col: 5.0),
        KeyDefinition(code: 0x23, name: "6^", keyIndex: 25, row: 1, col: 6.0),
        KeyDefinition(code: 0x24, name: "7&", keyIndex: 26, row: 1, col: 7.0),
        KeyDefinition(code: 0x25, name: "8*", keyIndex: 27, row: 1, col: 8.0),
        KeyDefinition(code: 0x26, name: "9(", keyIndex: 28, row: 1, col: 9.0),
        KeyDefinition(code: 0x27, name: "0)", keyIndex: 29, row: 1, col: 10.0),
        KeyDefinition(code: 0x2D, name: "-_", keyIndex: 30, row: 1, col: 11.0),
        KeyDefinition(code: 0x2E, name: "=+", keyIndex: 31, row: 1, col: 12.0),
        KeyDefinition(code: 0x2A, name: "Backspace", keyIndex: 103, row: 1, col: 13.0, width: 2.0),
        KeyDefinition(code: 0x49, name: "Insert", keyIndex: 116, row: 1, col: 15.5),
        KeyDefinition(code: 0x4A, name: "Home", keyIndex: 117, row: 1, col: 16.5),
        KeyDefinition(code: 0x4B, name: "PgUp", keyIndex: 118, row: 1, col: 17.5),
        KeyDefinition(code: 0x53, name: "NumLock", keyIndex: 32, row: 1, col: 19.0),
        KeyDefinition(code: 0x54, name: "Num /", keyIndex: 33, row: 1, col: 20.0),
        KeyDefinition(code: 0x55, name: "Num *", keyIndex: 34, row: 1, col: 21.0),
        KeyDefinition(code: 0x56, name: "Num -", keyIndex: 122, row: 1, col: 22.0),

        // Row 2: QWERTY Row
        KeyDefinition(code: 0x2B, name: "Tab", keyIndex: 37, row: 2, col: 0.0, width: 1.5),
        KeyDefinition(code: 0x14, name: "Q", keyIndex: 38, row: 2, col: 1.5),
        KeyDefinition(code: 0x1A, name: "W", keyIndex: 39, row: 2, col: 2.5),
        KeyDefinition(code: 0x08, name: "E", keyIndex: 40, row: 2, col: 3.5),
        KeyDefinition(code: 0x15, name: "R", keyIndex: 41, row: 2, col: 4.5),
        KeyDefinition(code: 0x17, name: "T", keyIndex: 42, row: 2, col: 5.5),
        KeyDefinition(code: 0x1C, name: "Y", keyIndex: 43, row: 2, col: 6.5),
        KeyDefinition(code: 0x18, name: "U", keyIndex: 44, row: 2, col: 7.5),
        KeyDefinition(code: 0x0C, name: "I", keyIndex: 45, row: 2, col: 8.5),
        KeyDefinition(code: 0x12, name: "O", keyIndex: 46, row: 2, col: 9.5),
        KeyDefinition(code: 0x13, name: "P", keyIndex: 47, row: 2, col: 10.5),
        KeyDefinition(code: 0x2F, name: "[{", keyIndex: 48, row: 2, col: 11.5),
        KeyDefinition(code: 0x30, name: "]}", keyIndex: 49, row: 2, col: 12.5),
        KeyDefinition(code: 0x31, name: "\\|", keyIndex: 67, row: 2, col: 13.5, width: 1.5),
        KeyDefinition(code: 0x4C, name: "Del", keyIndex: 119, row: 2, col: 15.5),
        KeyDefinition(code: 0x4D, name: "End", keyIndex: 120, row: 2, col: 16.5),
        KeyDefinition(code: 0x4E, name: "PgDn", keyIndex: 121, row: 2, col: 17.5),
        KeyDefinition(code: 0x5F, name: "Num 7", keyIndex: 50, row: 2, col: 19.0),
        KeyDefinition(code: 0x60, name: "Num 8", keyIndex: 51, row: 2, col: 20.0),
        KeyDefinition(code: 0x61, name: "Num 9", keyIndex: 52, row: 2, col: 21.0),
        KeyDefinition(code: 0x57, name: "Num +", keyIndex: 123, row: 2, col: 22.0),

        // Row 3: Home Row
        KeyDefinition(code: 0x39, name: "Caps", keyIndex: 55, row: 3, col: 0.0, width: 1.75),
        KeyDefinition(code: 0x04, name: "A", keyIndex: 56, row: 3, col: 1.75),
        KeyDefinition(code: 0x16, name: "S", keyIndex: 57, row: 3, col: 2.75),
        KeyDefinition(code: 0x07, name: "D", keyIndex: 58, row: 3, col: 3.75),
        KeyDefinition(code: 0x09, name: "F", keyIndex: 59, row: 3, col: 4.75),
        KeyDefinition(code: 0x0A, name: "G", keyIndex: 60, row: 3, col: 5.75),
        KeyDefinition(code: 0x0B, name: "H", keyIndex: 61, row: 3, col: 6.75),
        KeyDefinition(code: 0x0D, name: "J", keyIndex: 62, row: 3, col: 7.75),
        KeyDefinition(code: 0x0E, name: "K", keyIndex: 63, row: 3, col: 8.75),
        KeyDefinition(code: 0x0F, name: "L", keyIndex: 64, row: 3, col: 9.75),
        KeyDefinition(code: 0x33, name: ";:", keyIndex: 65, row: 3, col: 10.75),
        KeyDefinition(code: 0x34, name: "'\"", keyIndex: 66, row: 3, col: 11.75),
        KeyDefinition(code: 0x28, name: "Enter", keyIndex: 85, row: 3, col: 12.75, width: 2.25),
        KeyDefinition(code: 0x5C, name: "Num 4", keyIndex: 68, row: 3, col: 19.0),
        KeyDefinition(code: 0x5D, name: "Num 5", keyIndex: 69, row: 3, col: 20.0),
        KeyDefinition(code: 0x5E, name: "Num 6", keyIndex: 70, row: 3, col: 21.0),

        // Row 4: Shift Row
        KeyDefinition(code: 0xE1, name: "LShift", keyIndex: 73, row: 4, col: 0.0, width: 2.25),
        KeyDefinition(code: 0x1D, name: "Z", keyIndex: 74, row: 4, col: 2.25),
        KeyDefinition(code: 0x1B, name: "X", keyIndex: 75, row: 4, col: 3.25),
        KeyDefinition(code: 0x06, name: "C", keyIndex: 76, row: 4, col: 4.25),
        KeyDefinition(code: 0x19, name: "V", keyIndex: 77, row: 4, col: 5.25),
        KeyDefinition(code: 0x05, name: "B", keyIndex: 78, row: 4, col: 6.25),
        KeyDefinition(code: 0x11, name: "N", keyIndex: 79, row: 4, col: 7.25),
        KeyDefinition(code: 0x10, name: "M", keyIndex: 80, row: 4, col: 8.25),
        KeyDefinition(code: 0x36, name: ",<", keyIndex: 81, row: 4, col: 9.25),
        KeyDefinition(code: 0x37, name: ".>", keyIndex: 82, row: 4, col: 10.25),
        KeyDefinition(code: 0x38, name: "/?", keyIndex: 83, row: 4, col: 11.25),
        KeyDefinition(code: 0xE5, name: "RShift", keyIndex: 84, row: 4, col: 12.25, width: 2.75),
        KeyDefinition(code: 0x52, name: "Up", keyIndex: 106, row: 4, col: 16.5),
        KeyDefinition(code: 0x59, name: "Num 1", keyIndex: 86, row: 4, col: 19.0),
        KeyDefinition(code: 0x5A, name: "Num 2", keyIndex: 87, row: 4, col: 20.0),
        KeyDefinition(code: 0x5B, name: "Num 3", keyIndex: 88, row: 4, col: 21.0),
        KeyDefinition(code: 0x58, name: "Num Ent", keyIndex: 105, row: 4, col: 22.0),

        // Row 5: Bottom Row
        KeyDefinition(code: 0xE0, name: "LCtrl", keyIndex: 91, row: 5, col: 0.0, width: 1.25),
        KeyDefinition(code: 0xE3, name: "LWin/Cmd", keyIndex: 92, row: 5, col: 1.25, width: 1.25),
        KeyDefinition(code: 0xE2, name: "LAlt/Opt", keyIndex: 93, row: 5, col: 2.5, width: 1.25),
        KeyDefinition(code: 0x2C, name: "Space", keyIndex: 95, row: 5, col: 3.75, width: 6.25),
        KeyDefinition(code: 0xE6, name: "RAlt/Opt", keyIndex: 97, row: 5, col: 10.0, width: 1.25),
        KeyDefinition(code: 0x00, name: "FN", keyIndex: 98, row: 5, col: 11.25, width: 1.25, fnDisabled: true),
        KeyDefinition(code: 0x65, name: "Menu", keyIndex: 99, row: 5, col: 12.5, width: 1.25),
        KeyDefinition(code: 0xE4, name: "RCtrl", keyIndex: 101, row: 5, col: 13.75, width: 1.25),
        KeyDefinition(code: 0x50, name: "Left", keyIndex: 107, row: 5, col: 15.5),
        KeyDefinition(code: 0x51, name: "Down", keyIndex: 108, row: 5, col: 16.5),
        KeyDefinition(code: 0x4F, name: "Right", keyIndex: 109, row: 5, col: 17.5),
        KeyDefinition(code: 0x62, name: "Num 0", keyIndex: 104, row: 5, col: 19.0, width: 2.0),
        KeyDefinition(code: 0x63, name: "Num .", keyIndex: 110, row: 5, col: 21.0)
    ]

    public static func key(byIndex index: Int) -> KeyDefinition? {
        allKeys.first { $0.keyIndex == index }
    }
}
