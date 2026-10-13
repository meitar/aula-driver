import Foundation

public struct KeyboardProfile: Identifiable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var rgbMode: Int
    public var rgbBrightness: Int
    public var rgbSpeed: Int
    public var rgbDirection: Int
    public var rgbColorful: Bool
    public var rgbHexColor: String
    public var macLayoutEnabled: Bool
    public var keyRemaps: [Int: KeyAction]
    public var fnKeyRemaps: [Int: KeyAction]
    public var perKeyColors: [Int: String]
    public var responseLevel: Int
    public var sleepTime: Int
    public var gameModeEnabled: Bool
    public var macros: [KeyboardMacro]

    public init(
        id: UUID = UUID(),
        name: String,
        rgbMode: Int = 11,
        rgbBrightness: Int = 5,
        rgbSpeed: Int = 3,
        rgbDirection: Int = 0,
        rgbColorful: Bool = true,
        rgbHexColor: String = "#00FF88",
        macLayoutEnabled: Bool = true,
        keyRemaps: [Int: KeyAction] = [:],
        fnKeyRemaps: [Int: KeyAction] = [:],
        perKeyColors: [Int: String] = [:],
        responseLevel: Int = 1,
        sleepTime: Int = 1,
        gameModeEnabled: Bool = false,
        macros: [KeyboardMacro] = []
    ) {
        self.id = id
        self.name = name
        self.rgbMode = rgbMode
        self.rgbBrightness = rgbBrightness
        self.rgbSpeed = rgbSpeed
        self.rgbDirection = rgbDirection
        self.rgbColorful = rgbColorful
        self.rgbHexColor = rgbHexColor
        self.macLayoutEnabled = macLayoutEnabled
        self.keyRemaps = keyRemaps
        self.fnKeyRemaps = fnKeyRemaps
        self.perKeyColors = perKeyColors
        self.responseLevel = responseLevel
        self.sleepTime = sleepTime
        self.gameModeEnabled = gameModeEnabled
        self.macros = macros
    }

    public static let standardMac = KeyboardProfile(
        name: "Standard Mac",
        rgbMode: 11,
        rgbBrightness: 5,
        rgbSpeed: 3,
        rgbDirection: 0,
        rgbColorful: true,
        macLayoutEnabled: true
    )

    public static let gaming = KeyboardProfile(
        name: "Gaming (Win Locked)",
        rgbMode: 1, // Static
        rgbBrightness: 5,
        rgbSpeed: 5,
        rgbDirection: 0,
        rgbColorful: false,
        rgbHexColor: "#FF0033",
        macLayoutEnabled: false,
        responseLevel: 1, // 5ms
        sleepTime: 0, // Never sleep
        gameModeEnabled: true
    )

    public static let office = KeyboardProfile(
        name: "Office (Quiet RGB)",
        rgbMode: 7, // Breathing
        rgbBrightness: 2,
        rgbSpeed: 1,
        rgbDirection: 0,
        rgbColorful: false,
        rgbHexColor: "#3388FF",
        macLayoutEnabled: true,
        responseLevel: 3,
        sleepTime: 2
    )
}

public final class ProfileManager: @unchecked Sendable {
    public static let shared = ProfileManager()

    private let fileManager = FileManager.default
    private let profilesDirectory: URL

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.profilesDirectory = appSupport.appendingPathComponent("AulaDriver/profiles", isDirectory: true)
        try? fileManager.createDirectory(at: profilesDirectory, withIntermediateDirectories: true)
        ensureDefaultProfiles()
    }

    public func loadProfiles() -> [KeyboardProfile] {
        guard let files = try? fileManager.contentsOfDirectory(at: profilesDirectory, includingPropertiesForKeys: nil) else {
            return [KeyboardProfile.standardMac]
        }

        let jsonFiles = files.filter { $0.pathExtension == "json" }
        var list: [KeyboardProfile] = []
        let decoder = JSONDecoder()

        for file in jsonFiles {
            if let data = try? Data(contentsOf: file), let profile = try? decoder.decode(KeyboardProfile.self, from: data) {
                list.append(profile)
            }
        }

        if list.isEmpty {
            list = [KeyboardProfile.standardMac]
            saveProfile(KeyboardProfile.standardMac)
        }

        return list.sorted { $0.name < $1.name }
    }

    public func saveProfile(_ profile: KeyboardProfile) {
        let filename = "\(profile.id.uuidString).json"
        let fileURL = profilesDirectory.appendingPathComponent(filename)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(profile) {
            try? data.write(to: fileURL)
        }
    }

    public func deleteProfile(id: UUID) {
        let filename = "\(id.uuidString).json"
        let fileURL = profilesDirectory.appendingPathComponent(filename)
        try? fileManager.removeItem(at: fileURL)
    }

    public func exportProfile(_ profile: KeyboardProfile, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(profile)
        try data.write(to: url)
    }

    public func importProfile(from url: URL) throws -> KeyboardProfile {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        var profile = try decoder.decode(KeyboardProfile.self, from: data)
        profile.id = UUID() // Assign new ID upon import
        saveProfile(profile)
        return profile
    }

    private func ensureDefaultProfiles() {
        let existing = loadProfiles()
        if existing.isEmpty {
            saveProfile(KeyboardProfile.standardMac)
            saveProfile(KeyboardProfile.gaming)
            saveProfile(KeyboardProfile.office)
        }
    }
}
