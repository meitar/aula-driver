import AppKit
import AulaKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
public final class AppViewModel: ObservableObject {
    @Published public var wiredConnected = false
    @Published public var dongleConnected = false
    @Published public var wiredEndpoints: [HIDEndpointInfo] = []
    @Published public var wirelessEndpoints: [HIDEndpointInfo] = []
    @Published public var batteryPercent: Int?
    @Published public var logLines: [String] = []
    @Published public var isWorking = false

    // Screen Studio State
    @Published public var selectedImageURL: URL?
    @Published public var screenFitMode: ScreenFitMode = .contain
    @Published public var screenSlot: Int = 1
    @Published public var uploadProgress = DisplayUploadProgress(sentChunks: 0, totalChunks: 0)
    @Published public var galleryItems: [ScreenGalleryItem] = []

    // RGB Studio State
    @Published public var rgbMode: Int = 11 // Rolling (default)
    @Published public var rgbBrightness: Int = 5
    @Published public var rgbSpeed: Int = 3
    @Published public var rgbDirection: Int = 0
    @Published public var rgbColorful: Bool = true
    @Published public var rgbColor: Color = .green
    @Published public var perKeyMatrix = PerKeyRGBMatrix()

    // Key Remap State
    @Published public var macLayoutEnabled: Bool = true
    @Published public var remapLayer: KeyRemapLayer = .normal
    @Published public var currentRemapTable = KeyRemapTable(macLayoutEnabled: true)

    // Performance & Hardware State
    @Published public var responseLevel: Int = 1 // 5ms Fastest
    @Published public var sleepTime: Int = 1 // 1 minute
    @Published public var gameModeEnabled: Bool = false

    // Profiles
    @Published public var profiles: [KeyboardProfile] = []
    @Published public var selectedProfile: KeyboardProfile?

    private var deviceMonitor: HIDDeviceMonitor?
    private var batteryTimer: Timer?

    public init() {
        self.profiles = ProfileManager.shared.loadProfiles()
        self.selectedProfile = profiles.first
        self.galleryItems = ScreenGalleryManager.shared.loadItems()
        applyProfileToState(profiles.first ?? KeyboardProfile.standardMac)
        startMonitoring()
    }

    public func startMonitoring() {
        refreshEndpoints()
        let monitor = HIDDeviceMonitor()
        monitor.onDevicesChanged = { [weak self] in
            Task { @MainActor in
                self?.refreshEndpoints()
            }
        }
        monitor.start()
        self.deviceMonitor = monitor

        // Periodic battery query when dongle is connected
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.queryBatterySilently()
            }
        }
    }

    public func refreshEndpoints() {
        let wired = AulaDevice.scanEndpoints()
        let wireless = WirelessAulaDevice.scanEndpoints()

        self.wiredEndpoints = wired
        self.wirelessEndpoints = wireless
        self.wiredConnected = !wired.isEmpty
        self.dongleConnected = !wireless.isEmpty

        if wiredConnected {
            appendLog("Keyboard detected via USB-C (Wired mode)")
        }
        if dongleConnected {
            appendLog("2.4G Wireless receiver detected")
            queryBatterySilently()
        }
        if !wiredConnected && !dongleConnected {
            appendLog("No Aula F108 Pro devices connected")
        }
    }

    public func appendLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        logLines.insert("[\(timestamp)] \(message)", at: 0)
        if logLines.count > 100 { logLines.removeLast() }
    }

    // MARK: - Hardware Actions
    public func syncClock() {
        guard wiredConnected else {
            appendLog("Cannot sync clock: Keyboard must be connected via USB-C.")
            return
        }
        runAsyncAction(name: "Syncing Clock") {
            let device = try AulaDevice.connect()
            try device.syncClock()
            return "Clock synced to system time successfully."
        }
    }

    public func uploadDisplayImage() {
        guard let url = selectedImageURL else {
            appendLog("Select an image or GIF file first.")
            return
        }
        guard wiredConnected else {
            appendLog("Cannot upload display: Keyboard must be connected via USB-C.")
            return
        }

        let slot = screenSlot
        let fit = screenFitMode

        runAsyncAction(name: "Uploading Screen Media") {
            let encoded = try DisplayEncoder.encodeImage(at: url, fitMode: fit)
            await MainActor.run {
                self.uploadProgress = DisplayUploadProgress(sentChunks: 0, totalChunks: encoded.chunkCount)
                self.appendLog("Encoded \(encoded.frameCount) frame(s) (\(encoded.chunkCount) pages). Uploading...")
            }

            let device = try AulaDevice.connect()
            try device.uploadDisplayStream(encoded.data, slot: slot) { progress in
                Task { @MainActor in
                    self.uploadProgress = progress
                }
            }
            return "Display media uploaded to slot \(slot)."
        }
    }

    public func loadGallery() {
        self.galleryItems = ScreenGalleryManager.shared.loadItems()
    }

    public func addGIFToGallery(url: URL, title: String? = nil, fitMode: ScreenFitMode = .contain) {
        runAsyncAction(name: "Adding GIF to Gallery") {
            let item = try ScreenGalleryManager.shared.addItem(from: url, title: title, fitMode: fitMode)
            await MainActor.run {
                self.loadGallery()
            }
            return "Saved '\(item.title)' to Screen Gallery (\(item.frameCount) frames, \(item.chunkCount) pages)."
        }
    }

    public func activateGalleryItem(_ item: ScreenGalleryItem) {
        guard wiredConnected else {
            appendLog("Cannot activate GIF: Keyboard must be connected via USB-C.")
            return
        }

        runAsyncAction(name: "Activating Screen Animation") {
            let stream = try ScreenGalleryManager.shared.getStream(for: item)
            await MainActor.run {
                self.uploadProgress = DisplayUploadProgress(sentChunks: 0, totalChunks: item.chunkCount)
                self.appendLog("Streaming '\(item.title)' (\(item.frameCount) frames, \(item.chunkCount) pages)...")
            }

            let device = try AulaDevice.connect()
            try device.uploadDisplayStream(stream, slot: 1) { progress in
                Task { @MainActor in
                    self.uploadProgress = progress
                }
            }

            try ScreenGalleryManager.shared.setActive(id: item.id)
            await MainActor.run {
                self.loadGallery()
            }
            return "'\(item.title)' is now active on the keyboard screen!"
        }
    }

    public func removeGalleryItem(_ item: ScreenGalleryItem) {
        do {
            try ScreenGalleryManager.shared.removeItem(id: item.id)
            loadGallery()
            appendLog("Removed '\(item.title)' from gallery.")
        } catch {
            appendLog("Failed to delete gallery item: \(error.localizedDescription)")
        }
    }

    public func applyRGB() {
        let mode = rgbMode
        let brightness = rgbBrightness
        let speed = rgbSpeed
        let direction = rgbDirection
        let colorful = rgbColorful
        let colorInt = colorToRGBInt(rgbColor)

        runAsyncAction(name: "Applying RGB") {
            if self.wiredConnected {
                let device = try AulaDevice.connect()
                try device.applyRGB(
                    mode: mode,
                    brightness: brightness,
                    speed: speed,
                    direction: direction,
                    colorful: colorful,
                    color: colorInt
                )
            } else if self.dongleConnected {
                let wireless = try WirelessAulaDevice.connect()
                try wireless.applyRGB(
                    mode: mode,
                    brightness: brightness,
                    speed: speed,
                    direction: direction,
                    colorful: colorful,
                    color: colorInt
                )
            } else {
                throw AulaError.deviceNotFound
            }
            return "RGB applied: Mode \(mode), B\(brightness) S\(speed)"
        }
    }

    public func applyKeyRemap() {
        guard wiredConnected else {
            appendLog("Key remapping requires USB-C wired connection.")
            return
        }

        currentRemapTable.macLayoutEnabled = macLayoutEnabled
        let buffer = currentRemapTable.buildBuffer()
        let layer = remapLayer

        runAsyncAction(name: "Applying Key Remap") {
            let device = try AulaDevice.connect()
            try device.applyKeyRemap(layer: layer, table: buffer)
            return "Remap table written to keyboard memory (\(layer == .normal ? "Normal Layer" : "FN Layer"))."
        }
    }

    public func applyPerformance() {
        let level = responseLevel
        let sleep = sleepTime

        runAsyncAction(name: "Applying Performance") {
            if self.wiredConnected {
                let device = try AulaDevice.connect()
                try device.applyPerformance(responseLevel: level, sleepTime: sleep)
            } else if self.dongleConnected {
                let wireless = try WirelessAulaDevice.connect()
                try wireless.applyPerformance(level: level, sleepTime: sleep)
            } else {
                throw AulaError.deviceNotFound
            }
            return "Performance applied: Debounce Level \(level), Sleep \(sleep)."
        }
    }

    public func toggleGameMode(_ enabled: Bool) {
        self.gameModeEnabled = enabled
        let level = responseLevel
        let sleep = sleepTime

        runAsyncAction(name: "Game Mode \(enabled ? "On" : "Off")") {
            if self.dongleConnected {
                let wireless = try WirelessAulaDevice.connect()
                try wireless.setGameMode(enabled: enabled, level: level, sleepTime: sleep)
            }
            return "Game Mode \(enabled ? "enabled (Win Lock on)" : "disabled")."
        }
    }

    public func queryBattery() {
        guard dongleConnected else {
            appendLog("Battery query requires 2.4G wireless receiver.")
            return
        }
        runAsyncAction(name: "Querying Battery") {
            let wireless = try WirelessAulaDevice.connect()
            if let p = try wireless.queryBattery() {
                await MainActor.run { self.batteryPercent = p }
                return "Battery Level: \(p)%"
            } else {
                return "No battery response from receiver."
            }
        }
    }

    private func queryBatterySilently() {
        Task {
            if let wireless = try? WirelessAulaDevice.connect(),
               let p = try? wireless.queryBattery() {
                self.batteryPercent = p
            }
        }
    }

    // MARK: - Profile Management
    public func selectProfile(_ profile: KeyboardProfile) {
        self.selectedProfile = profile
        applyProfileToState(profile)
        appendLog("Switched to profile: \(profile.name)")
        applyRGB()
        if wiredConnected {
            applyKeyRemap()
        }
    }

    public func saveCurrentProfile() {
        guard var profile = selectedProfile else { return }
        profile.rgbMode = rgbMode
        profile.rgbBrightness = rgbBrightness
        profile.rgbSpeed = rgbSpeed
        profile.rgbDirection = rgbDirection
        profile.rgbColorful = rgbColorful
        profile.rgbHexColor = colorToHex(rgbColor)
        profile.macLayoutEnabled = macLayoutEnabled
        profile.responseLevel = responseLevel
        profile.sleepTime = sleepTime
        profile.gameModeEnabled = gameModeEnabled

        ProfileManager.shared.saveProfile(profile)
        self.profiles = ProfileManager.shared.loadProfiles()
        self.selectedProfile = profile
        appendLog("Profile '\(profile.name)' saved.")
    }

    public func createNewProfile(name: String) {
        let newProfile = KeyboardProfile(
            name: name,
            rgbMode: rgbMode,
            rgbBrightness: rgbBrightness,
            rgbSpeed: rgbSpeed,
            rgbDirection: rgbDirection,
            rgbColorful: rgbColorful,
            rgbHexColor: colorToHex(rgbColor),
            macLayoutEnabled: macLayoutEnabled
        )
        ProfileManager.shared.saveProfile(newProfile)
        self.profiles = ProfileManager.shared.loadProfiles()
        self.selectedProfile = newProfile
        appendLog("Created new profile: '\(name)'.")
    }

    private func applyProfileToState(_ profile: KeyboardProfile) {
        self.rgbMode = profile.rgbMode
        self.rgbBrightness = profile.rgbBrightness
        self.rgbSpeed = profile.rgbSpeed
        self.rgbDirection = profile.rgbDirection
        self.rgbColorful = profile.rgbColorful
        self.rgbColor = hexToColor(profile.rgbHexColor)
        self.macLayoutEnabled = profile.macLayoutEnabled
        self.responseLevel = profile.responseLevel
        self.sleepTime = profile.sleepTime
        self.gameModeEnabled = profile.gameModeEnabled
        self.currentRemapTable = KeyRemapTable(macLayoutEnabled: profile.macLayoutEnabled)
    }

    private func runAsyncAction(name: String, action: @escaping () async throws -> String) {
        isWorking = true
        appendLog("Starting: \(name)...")
        Task {
            do {
                let result = try await action()
                self.isWorking = false
                self.appendLog("✅ \(result)")
            } catch {
                self.isWorking = false
                self.appendLog("❌ \(name) failed: \(error.localizedDescription)")
            }
        }
    }

    private func colorToRGBInt(_ color: Color) -> Int {
        guard let components = NSColor(color).usingColorSpace(.sRGB) else { return 0x00FF88 }
        let r = Int(components.redComponent * 255)
        let g = Int(components.greenComponent * 255)
        let b = Int(components.blueComponent * 255)
        return (r << 16) | (g << 8) | b
    }

    private func colorToHex(_ color: Color) -> String {
        let val = colorToRGBInt(color)
        return String(format: "#%06X", val)
    }

    private func hexToColor(_ hex: String) -> Color {
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("#") { str.removeFirst() }
        guard let num = UInt32(str, radix: 16) else { return .green }
        let r = Double((num >> 16) & 0xFF) / 255.0
        let g = Double((num >> 8) & 0xFF) / 255.0
        let b = Double(num & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}
