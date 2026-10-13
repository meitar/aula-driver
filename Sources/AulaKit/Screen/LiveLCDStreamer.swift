import Foundation

public enum LiveLCDMode: Equatable, Sendable {
    case off
    case systemMonitor(interval: TimeInterval)
    case nowPlaying(interval: TimeInterval)
}

public final class LiveLCDStreamer: @unchecked Sendable {
    public static let shared = LiveLCDStreamer()

    private var timer: Timer?
    private let queue = DispatchQueue(label: "com.aulakit.live-lcd", qos: .utility)
    private var isStreaming = false
    public private(set) var currentMode: LiveLCDMode = .off

    private var lastPushedTrackKey: String?
    public var onNowPlayingStateChanged: (((title: String, artist: String, progress: Double, isPlaying: Bool)) -> Void)?
    public var onSystemMetricsChanged: (((cpu: Double, ramUsed: Double, ramTotal: Double)) -> Void)?
    public var onStreamProgress: ((DisplayUploadProgress) -> Void)?
    public var onStatusMessage: ((String) -> Void)?

    private init() {}

    public func start(mode: LiveLCDMode) {
        stop()
        self.currentMode = mode
        self.lastPushedTrackKey = nil

        switch mode {
        case .off:
            return

        case .systemMonitor(let interval):
            // Push initial frame immediately
            pushSystemFrame()
            // Set update interval (default at least 30s to keep display stable and readable)
            let safeInterval = max(interval, 20.0)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.timer = Timer.scheduledTimer(withTimeInterval: safeInterval, repeats: true) { [weak self] _ in
                    self?.pushSystemFrame()
                }
            }

        case .nowPlaying(let checkInterval):
            // Push current active track immediately
            pushNowPlayingFrame(force: true)
            // Poll for track changes every 3-5 seconds, but ONLY upload to LCD when track changes!
            let safePollInterval = max(checkInterval, 3.0)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.timer = Timer.scheduledTimer(withTimeInterval: safePollInterval, repeats: true) { [weak self] _ in
                    self?.pushNowPlayingFrame(force: false)
                }
            }
        }
    }

    public func stop() {
        DispatchQueue.main.async { [weak self] in
            self?.timer?.invalidate()
            self?.timer = nil
        }
        self.currentMode = .off
        self.lastPushedTrackKey = nil
    }

    public func triggerManualRefresh() {
        switch currentMode {
        case .systemMonitor:
            pushSystemFrame()
        case .nowPlaying:
            pushNowPlayingFrame(force: true)
        case .off:
            break
        }
    }

    public func pushSystemFrame() {
        guard !isStreaming else { return }
        queue.async { [weak self] in
            guard let self else { return }
            guard !self.isStreaming else { return }
            self.isStreaming = true
            defer { self.isStreaming = false }

            let cpu = SystemMetricsProvider.cpuLoad()
            let (ramUsed, ramTotal) = SystemMetricsProvider.ramMemory()

            DispatchQueue.main.async {
                self.onSystemMetricsChanged?((cpu: cpu, ramUsed: ramUsed, ramTotal: ramTotal))
                self.onStatusMessage?("Updating Mac System Monitor on screen...")
            }

            let stream = LCDCanvasRenderer.renderSystemMonitor(
                cpuPercent: cpu,
                ramUsedGB: ramUsed,
                ramTotalGB: ramTotal,
                batteryPercent: nil
            )

            if let device = try? AulaDevice.connect() {
                try? device.uploadDisplayStream(stream, slot: 1) { progress in
                    DispatchQueue.main.async {
                        self.onStreamProgress?(progress)
                    }
                }
                DispatchQueue.main.async {
                    self.onStatusMessage?("Live Mac System Monitor active on screen.")
                }
            }
        }
    }

    public func pushNowPlayingFrame(force: Bool = false) {
        guard !isStreaming else { return }
        queue.async { [weak self] in
            guard let self else { return }
            guard !self.isStreaming else { return }

            let info = SystemMetricsProvider.nowPlaying()
            let title = info?.title ?? "No Media Playing"
            let artist = info?.artist ?? "macOS Audio"
            let progress = info?.progress ?? 0.0
            let trackKey = "\(title)||||\(artist)"

            DispatchQueue.main.async {
                self.onNowPlayingStateChanged?((title: title, artist: artist, progress: progress, isPlaying: info != nil))
            }

            // Only upload to LCD if forced OR track changed!
            if !force && trackKey == self.lastPushedTrackKey {
                // Track is unchanged; keep LCD screen solid and stable without flashing
                return
            }

            self.isStreaming = true
            defer { self.isStreaming = false }
            self.lastPushedTrackKey = trackKey

            DispatchQueue.main.async {
                self.onStatusMessage?("Pushing '\(title)' by \(artist) to screen...")
            }

            let stream = LCDCanvasRenderer.renderNowPlaying(
                title: title,
                artist: artist,
                progress: progress
            )

            if let device = try? AulaDevice.connect() {
                try? device.uploadDisplayStream(stream, slot: 1) { progress in
                    DispatchQueue.main.async {
                        self.onStreamProgress?(progress)
                    }
                }
                DispatchQueue.main.async {
                    self.onStatusMessage?("Now Playing: '\(title)' active on screen.")
                }
            }
        }
    }
}
