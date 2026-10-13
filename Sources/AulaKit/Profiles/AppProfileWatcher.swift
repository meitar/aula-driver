import Foundation
#if canImport(AppKit)
import AppKit
#endif

public struct AppProfileRule: Codable, Identifiable, Sendable {
    public var id: String { bundleIdentifier }
    public let bundleIdentifier: String
    public let applicationName: String
    public var profileName: String

    public init(bundleIdentifier: String, applicationName: String, profileName: String) {
        self.bundleIdentifier = bundleIdentifier
        self.applicationName = applicationName
        self.profileName = profileName
    }
}

public final class AppProfileWatcher: @unchecked Sendable {
    public static let shared = AppProfileWatcher()

    private var observer: NSObjectProtocol?
    public var rules: [AppProfileRule] = []
    public var onProfileSwitchRequested: ((String) -> Void)?
    public private(set) var isWatching = false

    private let storageURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let baseDir = appSupport.appendingPathComponent("AulaDriver", isDirectory: true)
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        self.storageURL = baseDir.appendingPathComponent("app_rules.json")
        loadRules()
    }

    public func start() {
        guard !isWatching else { return }
        isWatching = true

        #if canImport(AppKit)
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleID = app.bundleIdentifier else { return }

            if let rule = self.rules.first(where: { $0.bundleIdentifier == bundleID }) {
                self.onProfileSwitchRequested?(rule.profileName)
            }
        }
        #endif
    }

    public func stop() {
        guard isWatching else { return }
        #if canImport(AppKit)
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            self.observer = nil
        }
        #endif
        isWatching = false
    }

    public func addRule(bundleIdentifier: String, appName: String, profileName: String) {
        rules.removeAll { $0.bundleIdentifier == bundleIdentifier }
        rules.append(AppProfileRule(bundleIdentifier: bundleIdentifier, applicationName: appName, profileName: profileName))
        saveRules()
    }

    public func removeRule(bundleIdentifier: String) {
        rules.removeAll { $0.bundleIdentifier == bundleIdentifier }
        saveRules()
    }

    private func saveRules() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(rules) {
            try? data.write(to: storageURL)
        }
    }

    private func loadRules() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        if let decoded = try? JSONDecoder().decode([AppProfileRule].self, from: data) {
            self.rules = decoded
        }
    }
}
