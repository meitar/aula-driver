import Foundation
import CoreGraphics
import CoreText

#if canImport(AppKit)
import AppKit
#endif

public enum LCDCanvasRenderer {
    public static let width = AulaConstants.displayWidth   // 240
    public static let height = AulaConstants.displayHeight // 135

    // MARK: - Frame Encoder Helper
    public static func encodeSingleFrame(drawing: (CGContext) -> Void) -> Data {
        let chunkCount = 16 // 256B header + 64800B data = 65056B = exactly 16 x 4096B chunks
        var stream = Data(repeating: 0xFF, count: chunkCount * AulaConstants.chunkLength)

        // Header
        stream[0] = 0x01 // 1 frame
        stream[1] = 0x05 // 5 centiseconds (doesn't matter for 1 frame)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return stream }
        let bytesPerRow = width * 4
        var canvas = [UInt8](repeating: 0, count: height * bytesPerRow)

        canvas.withUnsafeMutableBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return }
            guard let context = CGContext(
                data: base,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }

            context.setBlendMode(.copy)
            context.setFillColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.setBlendMode(.normal)

            drawing(context)
        }

        // Pack RGB565 little-endian
        let totalPixels = width * height
        let offset = AulaConstants.headerLength
        for pixelIndex in 0..<totalPixels {
            let base = pixelIndex * 4
            let red = UInt16(canvas[base]) >> 3
            let green = UInt16(canvas[base + 1]) >> 2
            let blue = UInt16(canvas[base + 2]) >> 3
            let pixel = (red << 11) | (green << 5) | blue
            stream[offset + pixelIndex * 2] = UInt8(pixel & 0xFF)
            stream[offset + pixelIndex * 2 + 1] = UInt8(pixel >> 8)
        }

        return stream
    }

    // MARK: - Live System Monitor Frame
    public static func renderSystemMonitor(
        cpuPercent: Double,
        ramUsedGB: Double,
        ramTotalGB: Double,
        batteryPercent: Int?,
        date: Date = Date()
    ) -> Data {
        return encodeSingleFrame { ctx in
            // Background
            ctx.setFillColor(red: 0.06, green: 0.08, blue: 0.12, alpha: 1.0)
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

            // Header bar
            ctx.setFillColor(red: 0.10, green: 0.14, blue: 0.22, alpha: 1.0)
            ctx.fill(CGRect(x: 0, y: height - 24, width: width, height: 24))

            // Time Formatter
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            let timeStr = formatter.string(from: date)

            // Header title
            drawText("AULA MAC MONITOR", x: 8, y: Double(height - 17), fontSize: 10, color: (0.0, 0.9, 1.0), in: ctx)
            drawText(timeStr, x: Double(width - 58), y: Double(height - 17), fontSize: 10, color: (0.7, 0.7, 0.8), in: ctx)

            // 1. CPU Bar
            let clampedCPU = min(max(cpuPercent, 0), 100)
            drawText("CPU", x: 8, y: 84, fontSize: 9, color: (0.8, 0.8, 0.9), in: ctx)
            drawText(String(format: "%.0f%%", clampedCPU), x: 40, y: 84, fontSize: 9, color: (0.0, 1.0, 0.6), in: ctx)
            drawProgressBar(x: 75, y: 82, width: 155, height: 10, fraction: clampedCPU / 100.0, color: (0.0, 0.85, 1.0), in: ctx)

            // 2. RAM Bar
            let ramFraction = ramTotalGB > 0 ? min(ramUsedGB / ramTotalGB, 1.0) : 0
            drawText("RAM", x: 8, y: 56, fontSize: 9, color: (0.8, 0.8, 0.9), in: ctx)
            drawText(String(format: "%.1fG", ramUsedGB), x: 38, y: 56, fontSize: 9, color: (1.0, 0.4, 0.8), in: ctx)
            drawProgressBar(x: 75, y: 54, width: 155, height: 10, fraction: ramFraction, color: (0.9, 0.2, 0.7), in: ctx)

            // 3. Battery / Status
            let batVal = batteryPercent ?? 100
            let batText = batteryPercent != nil ? "BAT \(batVal)%" : "KB CONNECTED"
            let batFraction = Double(batVal) / 100.0
            drawText("PWR", x: 8, y: 28, fontSize: 9, color: (0.8, 0.8, 0.9), in: ctx)
            drawText(batText, x: 38, y: 28, fontSize: 9, color: (0.4, 0.9, 0.4), in: ctx)
            drawProgressBar(x: 75, y: 26, width: 155, height: 10, fraction: batFraction, color: (0.2, 0.9, 0.4), in: ctx)

            // Bottom subtle indicator bar
            ctx.setFillColor(red: 0.0, green: 0.9, blue: 0.8, alpha: 0.6)
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: 2))
        }
    }

    // MARK: - Now Playing Media Frame
    public static func renderNowPlaying(
        title: String,
        artist: String,
        album: String? = nil,
        artwork: CGImage? = nil,
        progress: Double = 0.5
    ) -> Data {
        return encodeSingleFrame { ctx in
            // Dark velvet media player background
            ctx.setFillColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

            // Album Artwork (left side: 80x80 box)
            let artRect = CGRect(x: 10, y: 28, width: 80, height: 80)
            if let artwork {
                ctx.draw(artwork, in: artRect)
            } else {
                // Placeholder music icon background
                ctx.setFillColor(red: 0.15, green: 0.15, blue: 0.22, alpha: 1.0)
                ctx.fill(artRect)
                drawText("♪ MUSIC", x: 26, y: 64, fontSize: 11, color: (0.6, 0.6, 0.8), in: ctx)
            }

            // Border around album art
            ctx.setStrokeColor(red: 0.3, green: 0.3, blue: 0.4, alpha: 0.8)
            ctx.setLineWidth(1)
            ctx.stroke(artRect)

            // Right side metadata
            let cleanTitle = title.isEmpty ? "No Media Playing" : title
            let cleanArtist = artist.isEmpty ? "macOS Audio" : artist

            drawText("NOW PLAYING", x: 100, y: 96, fontSize: 8, color: (0.0, 0.9, 0.6), in: ctx)
            drawText(cleanTitle, x: 100, y: 76, fontSize: 11, color: (1.0, 1.0, 1.0), in: ctx)
            drawText(cleanArtist, x: 100, y: 58, fontSize: 9, color: (0.7, 0.7, 0.8), in: ctx)

            // Progress bar
            drawProgressBar(x: 100, y: 34, width: 130, height: 6, fraction: min(max(progress, 0), 1), color: (0.0, 0.8, 1.0), in: ctx)
        }
    }

    // MARK: - Drawing Primitives
    private static func drawProgressBar(
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        fraction: Double,
        color: (Double, Double, Double),
        in ctx: CGContext
    ) {
        // Track background
        ctx.setFillColor(red: 0.12, green: 0.14, blue: 0.20, alpha: 1.0)
        ctx.fill(CGRect(x: x, y: y, width: width, height: height))

        // Fill bar
        let fillW = max(0, min(width * fraction, width))
        if fillW > 0 {
            ctx.setFillColor(red: color.0, green: color.1, blue: color.2, alpha: 1.0)
            ctx.fill(CGRect(x: x, y: y, width: fillW, height: height))
        }

        // Border
        ctx.setStrokeColor(red: 0.25, green: 0.3, blue: 0.4, alpha: 0.6)
        ctx.setLineWidth(0.5)
        ctx.stroke(CGRect(x: x, y: y, width: width, height: height))
    }

    private static func drawText(
        _ text: String,
        x: Double,
        y: Double,
        fontSize: Double,
        color: (Double, Double, Double),
        in ctx: CGContext
    ) {
        let truncated = String(text.prefix(25))
        let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, fontSize, nil)
        let rgbColor = CGColor(srgbRed: color.0, green: color.1, blue: color.2, alpha: 1.0)
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): rgbColor
        ]
        let attrString = NSAttributedString(string: truncated, attributes: attrs)
        let line = CTLineCreateWithAttributedString(attrString)

        ctx.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, ctx)
    }
}

// MARK: - Mac System Metrics Provider
public enum SystemMetricsProvider {
    public static func cpuLoad() -> Double {
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        var numProcessors: natural_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numProcessors,
            &cpuInfo,
            &numCpuInfo
        )

        guard result == KERN_SUCCESS, let cpuInfo else { return 15.0 }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(numCpuInfo * UInt32(MemoryLayout<integer_t>.size)))
        }

        var totalTicks: Int32 = 0
        var idleTicks: Int32 = 0

        for i in 0..<Int(numProcessors) {
            let base = i * Int(CPU_STATE_MAX)
            let user = cpuInfo[base + Int(CPU_STATE_USER)]
            let system = cpuInfo[base + Int(CPU_STATE_SYSTEM)]
            let nice = cpuInfo[base + Int(CPU_STATE_NICE)]
            let idle = cpuInfo[base + Int(CPU_STATE_IDLE)]

            totalTicks += user + system + nice + idle
            idleTicks += idle
        }

        guard totalTicks > 0 else { return 15.0 }
        let usage = Double(totalTicks - idleTicks) / Double(totalTicks) * 100.0
        return max(0, min(100, usage))
    }

    public static func ramMemory() -> (usedGB: Double, totalGB: Double) {
        let hostPort = mach_host_self()
        var hostSize = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var vmStats = vm_statistics64()

        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(hostSize)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &hostSize)
            }
        }

        let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)
        let totalGB = totalBytes / 1_073_741_824.0

        guard result == KERN_SUCCESS else {
            return (usedGB: totalGB * 0.5, totalGB: totalGB)
        }

        let pageSize = Double(vm_kernel_page_size)
        let active = Double(vmStats.active_count) * pageSize
        let wired = Double(vmStats.wire_count) * pageSize
        let compressed = Double(vmStats.compressor_page_count) * pageSize
        let usedBytes = active + wired + compressed
        let usedGB = usedBytes / 1_073_741_824.0

        return (usedGB: max(0, usedGB), totalGB: totalGB)
    }

    public static func nowPlaying() -> (title: String, artist: String, progress: Double)? {
        #if canImport(AppKit)
        let isSpotify = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty
        let isMusic = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty

        guard isSpotify || isMusic else { return nil }

        let script: String
        if isSpotify {
            script = """
            tell application id "com.spotify.client"
                set s to player state
                if s is playing or s is paused then
                    return (get name of current track) & "|||" & (get artist of current track) & "|||" & (get player position) & "|||" & (get duration of current track / 1000)
                end if
            end tell
            return ""
            """
        } else {
            script = """
            tell application id "com.apple.Music"
                set s to player state
                if s is playing or s is paused then
                    return (get name of current track) & "|||" & (get artist of current track) & "|||" & (get player position) & "|||" & (get duration of current track)
                end if
            end tell
            return ""
            """
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        let start = Date()
        while process.isRunning {
            if Date().timeIntervalSince(start) > 1.5 {
                process.terminate()
                return nil
            }
            usleep(20_000)
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let parts = output.components(separatedBy: "|||")
        if parts.count >= 2, !parts[0].isEmpty {
            let title = parts[0]
            let artist = parts[1]
            var progress = 0.5
            if parts.count >= 4, let pos = Double(parts[2]), let dur = Double(parts[3]), dur > 0 {
                progress = min(max(pos / dur, 0.0), 1.0)
            }
            return (title: title, artist: artist, progress: progress)
        }
        #endif
        return nil
    }
}
