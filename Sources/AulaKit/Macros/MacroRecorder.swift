import Foundation
#if canImport(AppKit)
import AppKit
#endif

public final class MacroRecorder: @unchecked Sendable {
    public static let shared = MacroRecorder()

    #if canImport(AppKit)
    private var eventMonitor: Any?
    #endif

    public private(set) var isRecording = false
    private var lastEventTime: DispatchTime?
    public var onEventRecorded: ((MacroEvent) -> Void)?

    private init() {}

    public func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        lastEventTime = DispatchTime.now()

        #if canImport(AppKit)
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self, self.isRecording else { return event }

            let now = DispatchTime.now()
            if let lastTime = self.lastEventTime {
                let deltaNs = now.uptimeNanoseconds - lastTime.uptimeNanoseconds
                let deltaMs = UInt16(min(max(deltaNs / 1_000_000, 10), 5000))
                if deltaMs >= 10 {
                    let delayEvent = MacroEvent(type: .delay, delayMs: deltaMs)
                    self.onEventRecorded?(delayEvent)
                }
            }
            self.lastEventTime = now

            let hidCode = Self.macKeyCodeToHID(event.keyCode)
            let type: MacroEventType = event.type == .keyDown ? .keyDown : .keyUp
            let keyEvent = MacroEvent(type: type, value: hidCode)
            self.onEventRecorded?(keyEvent)

            return event
        }
        #endif
    }

    public func stopRecording() {
        guard isRecording else { return }
        #if canImport(AppKit)
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
        #endif
        isRecording = false
        lastEventTime = nil
    }

    public static func macKeyCodeToHID(_ keyCode: UInt16) -> UInt8 {
        switch keyCode {
        case 0: return 0x04  // A
        case 1: return 0x16  // S
        case 2: return 0x07  // D
        case 3: return 0x09  // F
        case 4: return 0x0B  // H
        case 5: return 0x0A  // G
        case 6: return 0x1D  // Z
        case 7: return 0x1B  // X
        case 8: return 0x06  // C
        case 9: return 0x19  // V
        case 11: return 0x05 // B
        case 12: return 0x14 // Q
        case 13: return 0x1A // W
        case 14: return 0x08 // E
        case 15: return 0x15 // R
        case 16: return 0x17 // Y
        case 17: return 0x1C // T
        case 18: return 0x1E // 1
        case 19: return 0x1F // 2
        case 20: return 0x20 // 3
        case 21: return 0x21 // 4
        case 22: return 0x23 // 6
        case 23: return 0x22 // 5
        case 24: return 0x2E // =
        case 25: return 0x26 // 9
        case 26: return 0x24 // 7
        case 27: return 0x2D // -
        case 28: return 0x25 // 8
        case 29: return 0x27 // 0
        case 30: return 0x30 // ]
        case 31: return 0x12 // O
        case 32: return 0x18 // U
        case 33: return 0x2F // [
        case 34: return 0x0C // I
        case 35: return 0x13 // P
        case 36: return 0x28 // Return
        case 37: return 0x0E // L
        case 38: return 0x0D // J
        case 39: return 0x34 // '
        case 40: return 0x0F // K
        case 41: return 0x33 // ;
        case 42: return 0x31 // \
        case 43: return 0x36 // ,
        case 44: return 0x38 // /
        case 45: return 0x11 // N
        case 46: return 0x10 // M
        case 47: return 0x37 // .
        case 48: return 0x2B // Tab
        case 49: return 0x2C // Space
        case 50: return 0x35 // `
        case 51: return 0x2A // Delete / Backspace
        case 53: return 0x29 // Escape
        case 55: return 0xE3 // Command (LWin)
        case 56: return 0xE1 // Shift (LShift)
        case 57: return 0x39 // CapsLock
        case 58: return 0xE2 // Option (LAlt)
        case 59: return 0xE0 // Control (LCtrl)
        case 123: return 0x50 // Left
        case 124: return 0x4F // Right
        case 125: return 0x51 // Down
        case 126: return 0x52 // Up
        default: return 0x04
        }
    }
}
