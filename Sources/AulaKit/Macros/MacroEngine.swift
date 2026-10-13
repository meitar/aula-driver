import Foundation

public enum MacroEngine {
    public static func serializeMacros(_ macros: [KeyboardMacro]) throws -> [UInt8] {
        let count = min(macros.count, AulaConstants.maxMacros)
        let totalEvents = macros.prefix(count).reduce(0) { $0 + $1.events.count }

        // Size limit check from reverse engineering: (macro_count + total_event_count) * 8 <= 2700
        guard (count + totalEvents) * 8 <= 2700 else {
            throw AulaError.hidFailed("Total macros and events exceed keyboard memory limit", 0)
        }

        var header = [UInt8](repeating: 0xFF, count: 400) // 100 slots * 4 bytes
        var dataArea = [UInt8]()

        for (index, macro) in macros.prefix(count).enumerated() {
            let offset = 400 + dataArea.count
            guard offset <= 0xFFFF else { break }

            // Write slot in header
            header[index * 4 + 0] = UInt8(offset & 0xFF)
            header[index * 4 + 1] = UInt8((offset >> 8) & 0xFF)
            header[index * 4 + 2] = 0x00
            header[index * 4 + 3] = 0x00

            // Write macro data block
            let eventCount = UInt16(macro.events.count)
            dataArea.append(UInt8(eventCount & 0xFF))
            dataArea.append(UInt8((eventCount >> 8) & 0xFF))
            dataArea.append(contentsOf: [UInt8](repeating: 0, count: 6)) // 6 bytes padding

            // Events (4 bytes each)
            for event in macro.events {
                var eventBytes = [UInt8](repeating: 0, count: 4)
                if event.type == .delay {
                    eventBytes[0] = UInt8(event.delayMs & 0xFF)
                    eventBytes[1] = UInt8((event.delayMs >> 8) & 0xFF)
                    eventBytes[2] = 0x00
                } else {
                    eventBytes[0] = 0x00
                    eventBytes[1] = 0x00
                    eventBytes[2] = event.value
                }
                eventBytes[3] = event.type.flagByte
                dataArea.append(contentsOf: eventBytes)
            }
        }

        var fullBuffer = header + dataArea

        // Pad to multiple of 64 bytes
        let remainder = fullBuffer.count % 64
        if remainder != 0 {
            fullBuffer.append(contentsOf: [UInt8](repeating: 0, count: 64 - remainder))
        }

        // Trailer 0xAA 0x55 at the very end
        if fullBuffer.count >= 2 {
            fullBuffer[fullBuffer.count - 2] = 0xAA
            fullBuffer[fullBuffer.count - 1] = 0x55
        }

        return fullBuffer
    }
}
