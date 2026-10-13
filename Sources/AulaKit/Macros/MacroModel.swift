import Foundation

public enum MacroEventType: String, Codable, Sendable {
    case keyDown
    case keyUp
    case mouseDown
    case mouseUp
    case delay

    public var flagByte: UInt8 {
        switch self {
        case .keyDown: return 0xB0
        case .keyUp: return 0x30
        case .mouseDown: return 0x90
        case .mouseUp: return 0x10
        case .delay: return 0x50
        }
    }
}

public struct MacroEvent: Identifiable, Codable, Sendable, Hashable {
    public var id = UUID()
    public var type: MacroEventType
    public var value: UInt8 // HID Scancode or mouse button (1=Left, 2=Right, 3=Middle)
    public var delayMs: UInt16 // Delay duration in ms (for delay type)

    public init(type: MacroEventType, value: UInt8 = 0, delayMs: UInt16 = 0) {
        self.type = type
        self.value = value
        self.delayMs = delayMs
    }

    public var displayString: String {
        switch type {
        case .keyDown:
            let keyName = KeyCatalog.allKeys.first(where: { $0.code == value })?.name ?? "Key \(value)"
            return "▼ Press \(keyName)"
        case .keyUp:
            let keyName = KeyCatalog.allKeys.first(where: { $0.code == value })?.name ?? "Key \(value)"
            return "▲ Release \(keyName)"
        case .mouseDown:
            return "▼ Mouse Button \(value) Down"
        case .mouseUp:
            return "▲ Mouse Button \(value) Up"
        case .delay:
            return "⏳ Wait \(delayMs) ms"
        }
    }
}

public struct KeyboardMacro: Identifiable, Codable, Sendable, Hashable {
    public var id = UUID()
    public var name: String
    public var playTimes: Int
    public var events: [MacroEvent]

    public init(name: String, playTimes: Int = 1, events: [MacroEvent] = []) {
        self.name = name
        self.playTimes = playTimes
        self.events = events
    }
}
