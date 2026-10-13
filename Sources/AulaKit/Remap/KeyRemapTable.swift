import Foundation

public enum KeyAction: Hashable, Sendable, Codable {
    case defaultBehavior
    case key(modifiers: UInt8, scancode: UInt8)
    case consumer(code: UInt8)
    case mouse(button: UInt8)
    case macro(index: UInt8, loopCount: UInt8)

    public var displayDescription: String {
        switch self {
        case .defaultBehavior:
            return "Default"
        case .key(let mods, let code):
            var parts: [String] = []
            if mods & 0x01 != 0 { parts.append("Ctrl") }
            if mods & 0x02 != 0 { parts.append("Shift") }
            if mods & 0x04 != 0 { parts.append("Alt/Opt") }
            if mods & 0x08 != 0 { parts.append("Cmd/Win") }
            if mods & 0x10 != 0 { parts.append("RCtrl") }
            if mods & 0x20 != 0 { parts.append("RShift") }
            if mods & 0x40 != 0 { parts.append("ROpt") }
            if mods & 0x80 != 0 { parts.append("RCmd") }
            let keyName = KeyCatalog.allKeys.first(where: { $0.code == code })?.name ?? "0x\(String(code, radix: 16))"
            if code != 0 { parts.append(keyName) }
            return parts.isEmpty ? "None" : parts.joined(separator: "+")
        case .consumer(let code):
            switch code {
            case 0xCD: return "Play/Pause"
            case 0xB7: return "Stop"
            case 0xB6: return "Prev Track"
            case 0xB5: return "Next Track"
            case 0xE9: return "Volume Up"
            case 0xEA: return "Volume Down"
            case 0xE2: return "Mute"
            default: return "Media (0x\(String(code, radix: 16)))"
            }
        case .mouse(let btn):
            switch btn {
            case 1: return "Left Click"
            case 2: return "Right Click"
            case 3: return "Middle Click"
            default: return "Mouse \(btn)"
            }
        case .macro(let idx, let loops):
            return "Macro \(idx) (x\(loops))"
        }
    }
}

public struct KeyRemapTable: Sendable, Codable {
    public var layer: KeyRemapLayer
    public var actions: [Int: KeyAction] = [:] // keyIndex -> action
    public var macLayoutEnabled: Bool = false

    public init(layer: KeyRemapLayer = .normal, actions: [Int: KeyAction] = [:], macLayoutEnabled: Bool = false) {
        self.layer = layer
        self.actions = actions
        self.macLayoutEnabled = macLayoutEnabled
    }

    public mutating func setAction(_ action: KeyAction, for keyIndex: Int) {
        actions[keyIndex] = action
    }

    public mutating func resetKey(_ keyIndex: Int) {
        actions.removeValue(forKey: keyIndex)
    }

    public mutating func resetAll() {
        actions.removeAll()
        macLayoutEnabled = false
    }

    public func buildBuffer() -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: AulaConstants.remapTableLength) // 576 bytes

        var effectiveActions = actions

        // Apply Mac Layout swap if requested
        if macLayoutEnabled && layer == .normal {
            // KeyIndex 92 = LWin -> map to Left Option (Modifier bit 0x04)
            // KeyIndex 93 = LAlt -> map to Left Command (Modifier bit 0x08)
            effectiveActions[92] = .key(modifiers: 0x04, scancode: 0x00) // LWin -> Opt
            effectiveActions[93] = .key(modifiers: 0x08, scancode: 0x00) // LAlt -> Cmd
        }

        for (keyIndex, action) in effectiveActions where keyIndex > 0 && keyIndex < AulaConstants.remapSlots {
            let offset = keyIndex * AulaConstants.remapSlotBytes
            guard offset + 3 < 574 else { continue }

            switch action {
            case .defaultBehavior:
                buffer[offset + 0] = 0x00
                buffer[offset + 1] = 0x00
                buffer[offset + 2] = 0x00
                buffer[offset + 3] = 0x00

            case .key(let mods, let scancode):
                buffer[offset + 0] = 0x02
                buffer[offset + 1] = mods
                buffer[offset + 2] = scancode
                buffer[offset + 3] = 0x00

            case .consumer(let code):
                buffer[offset + 0] = 0x03
                buffer[offset + 1] = code
                buffer[offset + 2] = 0x00
                buffer[offset + 3] = 0x00

            case .mouse(let btn):
                buffer[offset + 0] = 0x07
                buffer[offset + 1] = btn
                buffer[offset + 2] = 0x00
                buffer[offset + 3] = 0x00

            case .macro(let idx, let loops):
                buffer[offset + 0] = 0x06
                buffer[offset + 1] = idx
                buffer[offset + 2] = loops
                buffer[offset + 3] = 0x00
            }
        }

        // Little-endian trailer 0x55AA = 0xAA 0x55
        buffer[574] = 0xAA
        buffer[575] = 0x55
        return buffer
    }
}
