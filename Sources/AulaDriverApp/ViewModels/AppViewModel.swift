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
    @Published public var isScreenUploading = false
    @Published public var uploadingTitle = ""

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

    // Telemetry & Diagnostics
    @Published public var telemetry: DeviceTelemetrySnapshot?

    // Live Dynamic Screen
    @Published public var liveLCDMode: String = "gallery" // "gallery", "monitor", "nowPlaying"
    @Published public var nowPlayingTitle: String = "No Media Playing"
    @Published public var nowPlayingArtist: String = "macOS Audio"
    @Published public var nowPlayingProgress: Double = 0.0
    @Published public var nowPlayingActive: Bool = false
    @Published public var liveCPUPercent: Double = 0.0
    @Published public var liveRAMUsedGB: Double = 0.0
    @Published public var liveRAMTotalGB: Double = 16.0
    @Published public var liveLCDStatus: String = ""

    // Macros & Recording
    @Published public var isMacroRecording: Bool = false
    @Published public var activeMacros: [KeyboardMacro] = []

    // Advanced Remaps & Per-Key RGB
    @Published public var fnRemapTable = KeyRemapTable(layer: .fn)
    @Published public var perKeyHexColors: [Int: String] = [:]

    // Knob Events & App Watcher
    @Published public var recentKnobEvent: KnobEvent?
    @Published public var showKnobHUD: Bool = false
    @Published public var appRules: [AppProfileRule] = []
    @Published public var isAppWatcherActive: Bool = false

    // Profiles
    @Published public var profiles: [KeyboardProfile] = []
    @Published public var selectedProfile: KeyboardProfile?

    private var deviceMonitor: HIDDeviceMonitor?
    private var batteryTimer: Timer?

    public init() {
        self.profiles = ProfileManager.shared.loadProfiles()
        self.selectedProfile = profiles.first
        self.galleryItems = ScreenGalleryManager.shared.loadItems()
        self.activeMacros = profiles.first?.macros ?? []
        self.appRules = AppProfileWatcher.shared.rules
        applyProfileToState(profiles.first ?? KeyboardProfile.standardMac)
        startMonitoring()

        KnobEventMonitor.shared.onKnobAction = { [weak self] event in
            Task { @MainActor in
                self?.handleKnobEvent(event)
            }
        }
        KnobEventMonitor.shared.startMonitoring()

        AppProfileWatcher.shared.onProfileSwitchRequested = { [weak self] profileName in
            Task { @MainActor in
                self?.handleAppProfileSwitch(profileName)
            }
        }

        BatteryGuardian.shared.onBatteryUpdated = { [weak self] percent in
            Task { @MainActor in
                self?.batteryPercent = percent
            }
        }
        BatteryGuardian.shared.startMonitoring()

        LiveLCDStreamer.shared.onNowPlayingStateChanged = { [weak self] data in
            Task { @MainActor in
                self?.nowPlayingTitle = data.title
                self?.nowPlayingArtist = data.artist
                self?.nowPlayingProgress = data.progress
                self?.nowPlayingActive = data.isPlaying
            }
        }

        LiveLCDStreamer.shared.onSystemMetricsChanged = { [weak self] data in
            Task { @MainActor in
                self?.liveCPUPercent = data.cpu
                self?.liveRAMUsedGB = data.ramUsed
                self?.liveRAMTotalGB = data.ramTotal
            }
        }

        LiveLCDStreamer.shared.onStreamProgress = { [weak self] progress in
            Task { @MainActor in
                self?.uploadProgress = progress
                if progress.sentChunks >= progress.totalChunks {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        self?.uploadProgress = DisplayUploadProgress(sentChunks: 0, totalChunks: 0)
                    }
                }
            }
        }

        LiveLCDStreamer.shared.onStatusMessage = { [weak self] msg in
            Task { @MainActor in
                self?.liveLCDStatus = msg
                self?.appendLog(msg)
            }
        }

        refreshTelemetry()
    }

    public func startMonitoring() {
        refreshEndpoints()
        let monitor = HIDDeviceMonitor()
        monitor.onDevicesChanged = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.refreshEndpoints()
            }
        }
        monitor.start()
        self.deviceMonitor = monitor

        // Periodic battery query when dongle is connected
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.queryBatterySilently()
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
        guard !isScreenUploading else {
            appendLog("A screen upload is already in progress.")
            return
        }

        let slot = screenSlot
        let fit = screenFitMode
        let title = url.deletingPathExtension().lastPathComponent

        isScreenUploading = true
        uploadingTitle = title
        appendLog("Starting screen stream: '\(title)'...")

        Task.detached(priority: .userInitiated) {
            do {
                let encoded = try DisplayEncoder.encodeImage(at: url, fitMode: fit)
                await MainActor.run {
                    self.uploadProgress = DisplayUploadProgress(sentChunks: 0, totalChunks: encoded.chunkCount)
                    self.appendLog("Encoded \(encoded.frameCount) frame(s) (\(encoded.chunkCount) pages). Streaming over USB...")
                }

                let device = try AulaDevice.connect()
                try device.uploadDisplayStream(encoded.data, slot: slot) { progress in
                    Task { @MainActor in
                        self.uploadProgress = progress
                    }
                }

                await MainActor.run {
                    self.isScreenUploading = false
                    self.uploadingTitle = ""
                    self.appendLog("✅ Display media '\(title)' uploaded successfully to slot \(slot)!")
                }
            } catch {
                await MainActor.run {
                    self.isScreenUploading = false
                    self.uploadingTitle = ""
                    self.appendLog("❌ Display upload failed: \(error.localizedDescription)")
                }
            }
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
        guard !isScreenUploading else {
            appendLog("A screen upload is already in progress.")
            return
        }

        isScreenUploading = true
        uploadingTitle = item.title
        appendLog("Streaming '\(item.title)' from pre-encoded cache...")

        Task.detached(priority: .userInitiated) {
            do {
                let stream = try ScreenGalleryManager.shared.getStream(for: item)
                await MainActor.run {
                    self.uploadProgress = DisplayUploadProgress(sentChunks: 0, totalChunks: item.chunkCount)
                }

                let device = try AulaDevice.connect()
                try device.uploadDisplayStream(stream, slot: 1) { progress in
                    Task { @MainActor in
                        self.uploadProgress = progress
                    }
                }

                try ScreenGalleryManager.shared.setActive(id: item.id)
                await MainActor.run {
                    self.isScreenUploading = false
                    self.uploadingTitle = ""
                    self.loadGallery()
                    self.appendLog("✅ '\(item.title)' is now active on keyboard screen!")
                }
            } catch {
                await MainActor.run {
                    self.isScreenUploading = false
                    self.uploadingTitle = ""
                    self.appendLog("❌ Screen stream failed: \(error.localizedDescription)")
                }
            }
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

    public func refreshTelemetry() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let snapshot = DeviceTelemetryProvider.capture()
            Task { @MainActor in
                self.telemetry = snapshot
            }
        }
    }

    public func setLiveLCDMode(_ mode: String) {
        self.liveLCDMode = mode
        switch mode {
        case "monitor":
            LiveLCDStreamer.shared.start(mode: .systemMonitor(interval: 30.0))
            appendLog("Live Mac System Monitor started on screen (updates every 30s).")
        case "nowPlaying":
            LiveLCDStreamer.shared.start(mode: .nowPlaying(interval: 3.0))
            appendLog("Live Now Playing media widget started on screen (updates on track change).")
        default:
            LiveLCDStreamer.shared.stop()
            self.uploadProgress = DisplayUploadProgress(sentChunks: 0, totalChunks: 0)
            appendLog("Switched back to static GIF gallery.")
        }
    }

    public func refreshLiveLCD() {
        LiveLCDStreamer.shared.triggerManualRefresh()
    }

    public func startMacroRecording() {
        isMacroRecording = true
        var newMacro = KeyboardMacro(name: "Recorded Macro \(activeMacros.count + 1)", events: [])
        MacroRecorder.shared.onEventRecorded = { [weak self] event in
            Task { @MainActor in
                guard let self, self.isMacroRecording else { return }
                newMacro.events.append(event)
                if let idx = self.activeMacros.firstIndex(where: { $0.id == newMacro.id }) {
                    self.activeMacros[idx] = newMacro
                } else {
                    self.activeMacros.append(newMacro)
                }
            }
        }
        MacroRecorder.shared.startRecording()
        appendLog("Macro recording started. Type on keyboard...")
    }

    public func stopMacroRecording() {
        MacroRecorder.shared.stopRecording()
        isMacroRecording = false
        appendLog("Macro recording stopped. \(activeMacros.last?.events.count ?? 0) events recorded.")
    }

    public func uploadMacrosToDevice() {
        runAsyncAction(name: "Flashing macros to keyboard memory") {
            let device = try AulaDevice.connect()
            try device.uploadMacros(self.activeMacros)
            return "\(self.activeMacros.count) onboard macros synchronized to hardware memory."
        }
    }

    public func applyFNKeyRemap() {
        let table = fnRemapTable.buildBuffer()
        runAsyncAction(name: "Applying FN-Layer Remappings") {
            let device = try AulaDevice.connect()
            try device.applyKeyRemap(layer: .fn, table: table)
            return "FN-layer keybindings successfully applied."
        }
    }

    public func setKeyColor(keyIndex: Int, color: Color) {
        perKeyHexColors[keyIndex] = colorToHex(color)
    }

    public func applyPerKeyColorMatrix() {
        var matrix = PerKeyRGBMatrix()
        for (idx, hex) in perKeyHexColors {
            let cleanHex = hex.replacingOccurrences(of: "#", with: "")
            if let c = UInt32(cleanHex, radix: 16) {
                let r = UInt8((c >> 16) & 0xFF)
                let g = UInt8((c >> 8) & 0xFF)
                let b = UInt8(c & 0xFF)
                matrix.setColor(KeyRGBColor(red: r, green: g, blue: b), for: idx)
            }
        }
        let buffer = matrix.buildPayload()
        runAsyncAction(name: "Applying custom per-key colors") {
            let device = try AulaDevice.connect()
            try device.applyPerKeyRGB(buffer: buffer)
            try device.applyRGB(mode: 20, brightness: 5, speed: 3, direction: 0, colorful: false, color: 0)
            return "Per-key custom RGB matrix applied."
        }
    }

    public func toggleAppWatcher() {
        if isAppWatcherActive {
            AppProfileWatcher.shared.stop()
            isAppWatcherActive = false
            appendLog("Application profile auto-switching paused.")
        } else {
            AppProfileWatcher.shared.start()
            isAppWatcherActive = true
            appendLog("Application profile auto-switching active.")
        }
    }

    public func addAppRule(bundleID: String, name: String, profileName: String) {
        AppProfileWatcher.shared.addRule(bundleIdentifier: bundleID, appName: name, profileName: profileName)
        self.appRules = AppProfileWatcher.shared.rules
        appendLog("Added auto-switch rule for '\(name)' -> '\(profileName)'.")
    }

    public func removeAppRule(bundleID: String) {
        AppProfileWatcher.shared.removeRule(bundleIdentifier: bundleID)
        self.appRules = AppProfileWatcher.shared.rules
    }

    private func handleKnobEvent(_ event: KnobEvent) {
        self.recentKnobEvent = event
        self.showKnobHUD = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.showKnobHUD = false
        }
    }

    private func handleAppProfileSwitch(_ profileName: String) {
        if let target = profiles.first(where: { $0.name == profileName }) {
            selectProfile(target)
            appendLog("Auto-switched to profile '\(profileName)' for active app.")
        }
    }
}
