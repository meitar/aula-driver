import Foundation

public struct LightingPreset: Identifiable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let supportsSpeed: Bool
    public let supportsDirection: Bool
    public let supportsColor: Bool

    public init(id: Int, name: String, supportsSpeed: Bool = true, supportsDirection: Bool = false, supportsColor: Bool = true) {
        self.id = id
        self.name = name
        self.supportsSpeed = supportsSpeed
        self.supportsDirection = supportsDirection
        self.supportsColor = supportsColor
    }
}

public enum LightingController {
    public static let presets: [LightingPreset] = [
        LightingPreset(id: 0, name: "LED Off", supportsSpeed: false, supportsDirection: false, supportsColor: false),
        LightingPreset(id: 1, name: "Static", supportsSpeed: false, supportsDirection: false, supportsColor: true),
        LightingPreset(id: 2, name: "Single On", supportsSpeed: true, supportsDirection: false, supportsColor: true),
        LightingPreset(id: 3, name: "Single Off", supportsSpeed: true, supportsDirection: false, supportsColor: true),
        LightingPreset(id: 4, name: "Glittering", supportsSpeed: true, supportsDirection: false, supportsColor: true),
        LightingPreset(id: 5, name: "Falling", supportsSpeed: true, supportsDirection: false, supportsColor: true),
        LightingPreset(id: 6, name: "Colourful", supportsSpeed: true, supportsDirection: false, supportsColor: false),
        LightingPreset(id: 7, name: "Breathing", supportsSpeed: true, supportsDirection: false, supportsColor: true),
        LightingPreset(id: 8, name: "Spectrum", supportsSpeed: true, supportsDirection: false, supportsColor: false),
        LightingPreset(id: 9, name: "Outward", supportsSpeed: true, supportsDirection: false, supportsColor: true),
        LightingPreset(id: 10, name: "Scrolling", supportsSpeed: true, supportsDirection: true, supportsColor: true),
        LightingPreset(id: 11, name: "Rolling", supportsSpeed: true, supportsDirection: true, supportsColor: true),
        LightingPreset(id: 12, name: "Rotating", supportsSpeed: true, supportsDirection: true, supportsColor: true),
        LightingPreset(id: 13, name: "Explode", supportsSpeed: true, supportsDirection: false, supportsColor: true),
        LightingPreset(id: 14, name: "Launch", supportsSpeed: true, supportsDirection: false, supportsColor: true),
        LightingPreset(id: 15, name: "Ripples", supportsSpeed: true, supportsDirection: false, supportsColor: true),
        LightingPreset(id: 16, name: "Flowing", supportsSpeed: true, supportsDirection: true, supportsColor: true),
        LightingPreset(id: 17, name: "Pulsating", supportsSpeed: true, supportsDirection: false, supportsColor: true),
        LightingPreset(id: 18, name: "Tilt", supportsSpeed: true, supportsDirection: true, supportsColor: true),
        LightingPreset(id: 19, name: "Shuttle", supportsSpeed: true, supportsDirection: false, supportsColor: true)
    ]

    public static func preset(for id: Int) -> LightingPreset? {
        presets.first { $0.id == id }
    }

    public static func directionName(_ direction: Int) -> String {
        switch direction {
        case 0: return "Right"
        case 1: return "Down"
        case 2: return "Left"
        case 3: return "Up"
        default: return "Direction \(direction)"
        }
    }
}
