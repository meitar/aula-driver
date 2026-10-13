import Foundation
import UserNotifications

public final class BatteryGuardian: @unchecked Sendable {
    public static let shared = BatteryGuardian()

    private var timer: Timer?
    private var lastAlertPercent: Int?
    public private(set) var currentPercent: Int?
    public var onBatteryUpdated: ((Int) -> Void)?

    private init() {}

    private var canUseUNUserNotificationCenter: Bool {
        return Bundle.main.bundleIdentifier != nil
    }

    public func startMonitoring(interval: TimeInterval = 60.0) {
        stopMonitoring()

        // Request notification authorization only if running within an app bundle with a valid bundle identifier
        if canUseUNUserNotificationCenter {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.checkBattery()
            self.timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.checkBattery()
            }
        }
    }

    public func stopMonitoring() {
        DispatchQueue.main.async { [weak self] in
            self?.timer?.invalidate()
            self?.timer = nil
        }
    }

    private func checkBattery() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            guard let percent = try? WirelessAulaDevice.connect().queryBattery() else { return }

            DispatchQueue.main.async {
                self.currentPercent = percent
                self.onBatteryUpdated?(percent)
                self.evaluateAlert(percent: percent)
            }
        }
    }

    private func evaluateAlert(percent: Int) {
        // Thresholds: 20% and 10%
        if percent <= 20 {
            if lastAlertPercent == nil || (lastAlertPercent! > 20 && percent <= 20) || (lastAlertPercent! > 10 && percent <= 10) {
                sendNotification(percent: percent)
                lastAlertPercent = percent
            }
        } else {
            // Reset alert tracker once charged back above 20%
            lastAlertPercent = nil
        }
    }

    private func sendNotification(percent: Int) {
        if canUseUNUserNotificationCenter {
            let content = UNMutableNotificationContent()
            content.title = "Aula F108 Pro Battery Low"
            content.body = "Keyboard battery is at \(percent)%. Please connect USB Type-C cable to charge."
            content.sound = .default

            let request = UNNotificationRequest(identifier: "aula-low-battery-\(percent)", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        } else {
            // Fallback notification for SPM binary running without an .app bundle
            let script = "display notification \"Keyboard battery is at \(percent)%. Please connect USB Type-C cable to charge.\" with title \"Aula F108 Pro Battery Low\""
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            try? process.run()
        }
    }
}
