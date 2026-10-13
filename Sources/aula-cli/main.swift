import AulaKit
import Foundation

func printHelp() {
    print("""
    aula-cli: Aula F108 Pro Mechanical Keyboard Control Utility
    
    USAGE:
      aula-cli <command> [options]
      
    COMMANDS:
      status / telemetry            Display detailed hardware telemetry, descriptors, and latency
      info                          Show detected endpoints and device status
      clock sync                    Synchronize keyboard LCD clock to system time
      lcd monitor [--interval <s>]  Live Mac CPU/RAM/Battery system monitor on keyboard screen
      lcd now-playing               Live Spotify / Apple Music Now Playing display on screen
      rgb set [options]             Configure RGB backlighting
                                      --mode <0-19>       Preset effect ID (default: 11)
                                      --brightness <0-5>  Brightness level (default: 5)
                                      --speed <1-5>       Speed level (default: 3)
                                      --direction <0-3>   Direction (0:Right, 1:Down, 2:Left, 3:Up)
                                      --color <#RRGGBB>   Custom color (e.g. "#00FF88")
                                      --colorful          Enable rainbow cycling
      rgb custom [options]          Apply custom per-key lighting (--preset wasd|matrix|cyberpunk)
      rgb off                       Turn off keyboard backlighting
      rgb list                      List all 20 available lighting preset modes
      screen upload <path> [opts]   Directly upload image/GIF to keyboard LCD screen (240x135)
                                      --slot <1-255>      Slot number (default: 1)
                                      --fit <fit|fill|stretch>
      screen gallery list           List all saved animations in the GIF library
      screen gallery add <path>     Pre-encode and save a GIF to library (--name, --fit)
      screen gallery activate <id>  Instantly stream a saved animation to keyboard
      screen gallery remove <id>    Delete a saved animation from library
      macro flash                   Flash onboard macros from active profile into hardware memory
      remap mac-layout [on|off]     Toggle Mac layout mode (swaps Win and Alt)
      remap fn-layout               Apply custom FN layer keybindings
      remap reset                   Reset all key remappings to default
      perf [options]                Set performance and debounce latency
                                      --level <1-5>       Response level (1=Fastest 5ms, 5=21ms)
                                      --sleep <0-3>       Sleep timeout (0=None, 1=1m, 2=5m, 3=30m)
      battery                       Query battery percentage via 2.4G wireless receiver
      reset                         Factory reset keyboard display and configuration
    """)
}

func parseColorHex(_ hex: String) -> Int? {
    var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if cleaned.hasPrefix("#") { cleaned.removeFirst() }
    guard let val = UInt32(cleaned, radix: 16) else { return nil }
    return Int(val)
}

let args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first else {
    printHelp()
    exit(0)
}

do {
    switch command {
    case "help", "--help", "-h":
        printHelp()

    case "status", "telemetry":
        print("📊 Capturing Aula F108 Pro Hardware Telemetry...")
        let t = DeviceTelemetryProvider.capture()
        print("""
        ========================================================================
        AULA F108 PRO HARDWARE TELEMETRY & DIAGNOSTICS
        ========================================================================
        Connection Mode    : \(t.mode.rawValue)
        Product Name       : \(t.productName)
        Manufacturer       : \(t.manufacturer)
        USB VID:PID        : \(t.vendorHex):\(t.productHex)
        USB Bus Speed      : \(t.usbSpeed)
        USB Transport      : \(t.transport)
        Active Endpoints   : \(t.endpointCount) interface endpoint(s)
        Battery Status     : \(t.batteryPercent != nil ? "\(t.batteryPercent!)% (\(t.isCharging ? "Charging" : "Battery"))" : (t.isCharging ? "Wired Power (AC)" : "Unknown"))
        Round-trip Latency : \(String(format: "%.2f ms", t.roundTripLatencyMs))
        Host Lock Keys     : CapsLock [\(t.capsLockActive ? "ON" : "OFF")]  NumLock [\(t.numLockActive ? "ON" : "OFF")]  ScrollLock [\(t.scrollLockActive ? "ON" : "OFF")]
        ========================================================================
        """)

    case "lcd":
        guard args.count > 1 else {
            print("Usage: aula-cli lcd <monitor|now-playing>")
            exit(1)
        }
        let lcdSub = args[1]
        let device = try AulaDevice.connect()
        if lcdSub == "monitor" {
            print("🖥️  Starting Live Mac System Monitor stream (press Ctrl+C to stop)...")
            let cpu = SystemMetricsProvider.cpuLoad()
            let (ramUsed, ramTotal) = SystemMetricsProvider.ramMemory()
            print("  • Pushing initial frame: CPU \(String(format: "%.0f%%", cpu)) | RAM \(String(format: "%.1f", ramUsed))/\(String(format: "%.0f", ramTotal)) GB")
            let frame = LCDCanvasRenderer.renderSystemMonitor(cpuPercent: cpu, ramUsedGB: ramUsed, ramTotalGB: ramTotal, batteryPercent: nil)
            try device.uploadDisplayStream(frame, slot: 1) { _ in }
            print("✅ Mac System Monitor active on keyboard screen.")
        } else if lcdSub == "now-playing" {
            var customTitle: String?
            var customArtist: String?
            var i = 2
            while i < args.count {
                if args[i] == "--title", i + 1 < args.count {
                    customTitle = args[i + 1]
                    i += 2
                } else if args[i] == "--artist", i + 1 < args.count {
                    customArtist = args[i + 1]
                    i += 2
                } else {
                    i += 1
                }
            }

            print("🎵 Fetching Now Playing media from macOS...")
            let info = SystemMetricsProvider.nowPlaying()
            let title = customTitle ?? info?.title ?? "No Media Playing"
            let artist = customArtist ?? info?.artist ?? "macOS Audio"
            let progress = info?.progress ?? 0.5
            print("🎶 Track: '\(title)' by \(artist) (Progress: \(Int(progress * 100))%)")
            let frame = LCDCanvasRenderer.renderNowPlaying(title: title, artist: artist, progress: progress)
            try device.uploadDisplayStream(frame, slot: 1) { progress in
                let barLength = 30
                let filled = Int(progress.fraction * Double(barLength))
                let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: max(0, barLength - filled))
                print("\r[\(bar)] \(progress.percent)% (\(progress.sentChunks)/\(progress.totalChunks))", terminator: "")
                fflush(stdout)
            }
            print("\n✅ Now Playing widget pushed to keyboard screen.")
        } else {
            print("Unknown lcd command: '\(lcdSub)'. Supported: monitor, now-playing.")
            exit(1)
        }

    case "info":
        print("🔍 Scanning for Aula F108 Pro devices...")
        let wiredEndpoints = AulaDevice.scanEndpoints()
        let wirelessEndpoints = WirelessAulaDevice.scanEndpoints()

        print("\nWired USB Endpoints (\(wiredEndpoints.count)):")
        if wiredEndpoints.isEmpty {
            print("  (None detected - check USB-C connection)")
        } else {
            for ep in wiredEndpoints {
                print("  • \(ep.summary)")
            }
        }

        print("\n2.4G Wireless Dongle Endpoints (\(wirelessEndpoints.count)):")
        if wirelessEndpoints.isEmpty {
            print("  (None detected - check 2.4G USB receiver)")
        } else {
            for ep in wirelessEndpoints {
                print("  • \(ep.summary)")
            }
        }

    case "clock":
        guard args.count > 1, args[1] == "sync" else {
            print("Usage: aula-cli clock sync")
            exit(1)
        }
        print("⏰ Syncing keyboard clock to system time...")
        let device = try AulaDevice.connect()
        try device.syncClock()
        print("✅ Keyboard LCD clock successfully synchronized.")

    case "rgb":
        guard args.count > 1 else {
            print("Usage: aula-cli rgb <set|off|list>")
            exit(1)
        }
        let sub = args[1]
        switch sub {
        case "list":
            print("Aula F108 Pro RGB Lighting Modes:")
            for p in LightingController.presets {
                var notes: [String] = []
                if p.supportsSpeed { notes.append("Speed") }
                if p.supportsDirection { notes.append("Direction") }
                if p.supportsColor { notes.append("Color") }
                let noteStr = notes.isEmpty ? "" : " (\(notes.joined(separator: ", ")))"
                print(String(format: "  %2d: %@%@", p.id, p.name, noteStr))
            }

        case "off":
            print("💡 Turning off backlighting...")
            let device = try AulaDevice.connect()
            try device.applyRGB(mode: 0, brightness: 0, speed: 1, direction: 0, colorful: false, color: 0)
            print("✅ Backlight turned off.")

        case "set":
            var mode = 11
            var brightness = 5
            var speed = 3
            var direction = 0
            var colorful = true
            var color = 0x00FF88

            var i = 2
            while i < args.count {
                let opt = args[i]
                if opt == "--mode", i + 1 < args.count {
                    mode = Int(args[i + 1]) ?? mode
                    i += 2
                } else if opt == "--brightness", i + 1 < args.count {
                    brightness = Int(args[i + 1]) ?? brightness
                    i += 2
                } else if opt == "--speed", i + 1 < args.count {
                    speed = Int(args[i + 1]) ?? speed
                    i += 2
                } else if opt == "--direction", i + 1 < args.count {
                    direction = Int(args[i + 1]) ?? direction
                    i += 2
                } else if opt == "--color", i + 1 < args.count {
                    if let c = parseColorHex(args[i + 1]) {
                        color = c
                        colorful = false
                    }
                    i += 2
                } else if opt == "--colorful" {
                    colorful = true
                    i += 1
                } else {
                    i += 1
                }
            }

            print("💡 Applying RGB Mode \(mode) (Brightness: \(brightness), Speed: \(speed), Direction: \(direction))...")
            let device = try AulaDevice.connect()
            try device.applyRGB(
                mode: mode,
                brightness: brightness,
                speed: speed,
                direction: direction,
                colorful: colorful,
                color: color
            )
            print("✅ RGB lighting applied.")

        case "custom":
            print("🎨 Applying custom per-key RGB layout...")
            var matrix = PerKeyRGBMatrix()
            var preset = "wasd"
            if let idx = args.firstIndex(of: "--preset"), idx + 1 < args.count {
                preset = args[idx + 1].lowercased()
            }
            if preset == "wasd" {
                for k in KeyCatalog.allKeys {
                    if ["W", "A", "S", "D"].contains(k.name) {
                        matrix.setColor(KeyRGBColor(red: 255, green: 0, blue: 0), for: k.keyIndex)
                    } else if ["Left", "Right", "Up", "Down"].contains(k.name) {
                        matrix.setColor(KeyRGBColor(red: 0, green: 150, blue: 255), for: k.keyIndex)
                    } else {
                        matrix.setColor(KeyRGBColor(red: 30, green: 30, blue: 40), for: k.keyIndex)
                    }
                }
            } else if preset == "matrix" {
                for k in KeyCatalog.allKeys {
                    matrix.setColor(KeyRGBColor(red: 0, green: 255, blue: 40), for: k.keyIndex)
                }
            } else {
                for k in KeyCatalog.allKeys {
                    let r = UInt8(k.row * 40)
                    let b = UInt8(255 - k.row * 35)
                    matrix.setColor(KeyRGBColor(red: r, green: 10, blue: b), for: k.keyIndex)
                }
            }
            let device = try AulaDevice.connect()
            try device.applyPerKeyRGB(buffer: matrix.buildPayload())
            try device.applyRGB(mode: 20, brightness: 5, speed: 3, direction: 0, colorful: false, color: 0)
            print("✅ Custom per-key RGB matrix applied (Preset: \(preset)).")

        default:
            print("Unknown rgb subcommand: \(sub). Supported: set, off, list, custom.")
            exit(1)
        }

    case "screen":
        guard args.count > 1 else {
            print("Usage: aula-cli screen <upload|gallery> [options]")
            exit(1)
        }
        let screenSub = args[1]
        if screenSub == "gallery" {
            let gallerySub = args.count > 2 ? args[2] : "list"
            let manager = ScreenGalleryManager.shared

            switch gallerySub {
            case "list":
                let items = manager.loadItems()
                if items.isEmpty {
                    print("📁 Screen animation gallery is empty.")
                    print("Use 'aula-cli screen gallery add <path.gif> [--name \"Title\"]' to add your favorite GIFs.")
                } else {
                    print("🖼️  Aula Screen Animation Gallery (\(items.count) items):")
                    for (index, item) in items.enumerated() {
                        let activeMark = item.isActive ? " [ACTIVE]" : ""
                        print("  \(index + 1). \(item.title)\(activeMark)")
                        print("     Frames: \(item.frameCount) | Pages: \(item.chunkCount) (\(item.chunkCount * 4) KB) | ID: \(item.id.uuidString.prefix(8))")
                    }
                }

            case "add":
                guard args.count > 3 else {
                    print("Usage: aula-cli screen gallery add <path.gif> [--name \"Title\"] [--fit <fit|fill|stretch>]")
                    exit(1)
                }
                let filePath = args[3]
                var title: String?
                var fitMode: ScreenFitMode = .contain

                var i = 4
                while i < args.count {
                    if args[i] == "--name", i + 1 < args.count {
                        title = args[i + 1]
                        i += 2
                    } else if args[i] == "--fit", i + 1 < args.count {
                        let val = args[i + 1].lowercased()
                        if val == "fill" { fitMode = .cover }
                        else if val == "stretch" { fitMode = .stretch }
                        else { fitMode = .contain }
                        i += 2
                    } else {
                        i += 1
                    }
                }

                let url = URL(fileURLWithPath: filePath)
                print("⚡ Pre-encoding and saving '\(url.lastPathComponent)' into gallery...")
                let item = try manager.addItem(from: url, title: title, fitMode: fitMode)
                print("✅ Added '\(item.title)' to gallery (\(item.frameCount) frames, \(item.chunkCount) pages).")

            case "activate":
                guard args.count > 3 else {
                    print("Usage: aula-cli screen gallery activate <index|title|id>")
                    exit(1)
                }
                let target = args[3]
                let items = manager.loadItems()
                let matched: ScreenGalleryItem?
                if let num = Int(target), (1...items.count).contains(num) {
                    matched = items[num - 1]
                } else {
                    matched = items.first { $0.title.lowercased() == target.lowercased() || $0.id.uuidString.lowercased().hasPrefix(target.lowercased()) }
                }

                guard let item = matched else {
                    print("❌ Gallery item '\(target)' not found. Run 'aula-cli screen gallery list' to see available items.")
                    exit(1)
                }

                print("⚡ Instantly streaming '\(item.title)' to keyboard screen (\(item.frameCount) frames, \(item.chunkCount) pages)...")
                let stream = try manager.getStream(for: item)
                let device = try AulaDevice.connect()
                try device.uploadDisplayStream(stream, slot: 1) { progress in
                    let barLength = 30
                    let filled = Int(progress.fraction * Double(barLength))
                    let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: max(0, barLength - filled))
                    print("\r[\(bar)] \(progress.percent)% (\(progress.sentChunks)/\(progress.totalChunks))", terminator: "")
                    fflush(stdout)
                }
                try manager.setActive(id: item.id)
                print("\n✅ Animation '\(item.title)' is now active on keyboard screen!")

            case "remove", "delete":
                guard args.count > 3 else {
                    print("Usage: aula-cli screen gallery remove <index|title|id>")
                    exit(1)
                }
                let target = args[3]
                let items = manager.loadItems()
                let matched: ScreenGalleryItem?
                if let num = Int(target), (1...items.count).contains(num) {
                    matched = items[num - 1]
                } else {
                    matched = items.first { $0.title.lowercased() == target.lowercased() || $0.id.uuidString.lowercased().hasPrefix(target.lowercased()) }
                }

                guard let item = matched else {
                    print("❌ Gallery item '\(target)' not found.")
                    exit(1)
                }

                try manager.removeItem(id: item.id)
                print("✅ Removed '\(item.title)' from screen animation gallery.")

            default:
                print("Unknown gallery command: \(gallerySub). Supported: list, add, activate, remove.")
                exit(1)
            }
            break
        }

        guard screenSub == "upload", args.count > 2 else {
            print("Usage: aula-cli screen upload <file_path> [--slot <1-255>] [--fit <fit|fill|stretch>]")
            print("       aula-cli screen gallery <list|add|activate|remove>")
            exit(1)
        }
        let filePath = args[2]
        var slot = 1
        var fitMode: ScreenFitMode = .contain

        var i = 3
        while i < args.count {
            let opt = args[i]
            if opt == "--slot", i + 1 < args.count {
                slot = Int(args[i + 1]) ?? slot
                i += 2
            } else if opt == "--fit", i + 1 < args.count {
                let val = args[i + 1].lowercased()
                if val == "fill" { fitMode = .cover }
                else if val == "stretch" { fitMode = .stretch }
                else { fitMode = .contain }
                i += 2
            } else {
                i += 1
            }
        }

        let fileURL = URL(fileURLWithPath: filePath)
        print("🖼️  Encoding image '\(fileURL.lastPathComponent)' for 240x135 TFT screen (Fit: \(fitMode.title))...")
        let encoded = try DisplayEncoder.encodeImage(at: fileURL, fitMode: fitMode)
        print("📦 Encoded \(encoded.frameCount) frame(s), \(encoded.chunkCount) pages (\(encoded.data.count) bytes).")

        print("⚡ Uploading to keyboard display slot \(slot)...")
        let device = try AulaDevice.connect()
        try device.uploadDisplayStream(encoded.data, slot: slot) { progress in
            let barLength = 30
            let filled = Int(progress.fraction * Double(barLength))
            let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: max(0, barLength - filled))
            print("\r[\(bar)] \(progress.percent)% (\(progress.sentChunks)/\(progress.totalChunks))", terminator: "")
            fflush(stdout)
        }
        print("\n✅ Upload complete! Frame(s) active on keyboard screen.")

    case "remap":
        guard args.count > 1 else {
            print("Usage: aula-cli remap <mac-layout|reset>")
            exit(1)
        }
        let sub = args[1]
        let device = try AulaDevice.connect()
        if sub == "mac-layout" {
            let enable = args.count > 2 ? (args[2].lowercased() != "off") : true
            print("⌨️  Setting Mac Layout Mode (\(enable ? "Enabled: LWin->Opt, LAlt->Cmd" : "Disabled"))...")
            let table = KeyRemapTable(macLayoutEnabled: enable)
            try device.applyKeyRemap(layer: .normal, table: table.buildBuffer())
            print("✅ Mac layout remapping applied directly into keyboard memory.")
        } else if sub == "fn-layout" {
            print("⌨️  Applying FN-layer keybindings...")
            var table = KeyRemapTable(layer: .fn)
            // Vim navigation HJKL -> Arrows
            table.setAction(.key(modifiers: 0, scancode: 0x50), for: 61) // H -> Left
            table.setAction(.key(modifiers: 0, scancode: 0x51), for: 62) // J -> Down
            table.setAction(.key(modifiers: 0, scancode: 0x52), for: 63) // K -> Up
            table.setAction(.key(modifiers: 0, scancode: 0x4F), for: 64) // L -> Right
            try device.applyKeyRemap(layer: .fn, table: table.buildBuffer())
            print("✅ FN-layer remapping applied (Vim navigation: FN+HJKL -> Arrows).")
        } else if sub == "reset" {
            print("⌨️  Resetting all key remapping to default...")
            let table = KeyRemapTable()
            try device.applyKeyRemap(layer: .normal, table: table.buildBuffer())
            try device.applyKeyRemap(layer: .fn, table: table.buildBuffer())
            print("✅ Keys reset to default.")
        } else {
            print("Unknown remap subcommand: \(sub). Supported: mac-layout, fn-layout, reset.")
            exit(1)
        }

    case "macro":
        guard args.count > 1 else {
            print("Usage: aula-cli macro <flash|list>")
            exit(1)
        }
        let macroSub = args[1]
        let profile = ProfileManager.shared.loadProfiles().first ?? KeyboardProfile.standardMac
        if macroSub == "list" {
            print("Onboard Macros in active profile (\(profile.macros.count)):")
            for (idx, m) in profile.macros.enumerated() {
                print("  [\(idx)] \(m.name) (\(m.events.count) events, \(m.playTimes)x)")
            }
        } else if macroSub == "flash" {
            print("⚡ Flashing \(profile.macros.count) macro(s) to keyboard hardware memory...")
            let device = try AulaDevice.connect()
            try device.uploadMacros(profile.macros)
            print("✅ Macros successfully synchronized to keyboard hardware memory.")
        } else {
            print("Unknown macro command: \(macroSub). Supported: list, flash.")
            exit(1)
        }

    case "perf":
        var level = 1
        var sleep = 1
        var i = 1
        while i < args.count {
            if args[i] == "--level", i + 1 < args.count {
                level = Int(args[i + 1]) ?? level
                i += 2
            } else if args[i] == "--sleep", i + 1 < args.count {
                sleep = Int(args[i + 1]) ?? sleep
                i += 2
            } else {
                i += 1
            }
        }
        print("⚡ Setting response level: \(level) (debounce), Sleep timeout: \(sleep)...")
        let device = try AulaDevice.connect()
        try device.applyPerformance(responseLevel: level, sleepTime: sleep)
        print("✅ Performance parameters applied.")

    case "battery":
        print("🔋 Querying battery over 2.4G wireless receiver...")
        let wireless = try WirelessAulaDevice.connect()
        if let percent = try wireless.queryBattery() {
            print("🔋 Keyboard Battery: \(percent)%")
        } else {
            print("⚠️  No battery report received (ensure 2.4G mode is active and keyboard is awake).")
        }

    case "reset":
        print("⚠️  Initiating keyboard factory reset...")
        let device = try AulaDevice.connect()
        try device.factoryReset { status in
            print("  • \(status)")
        }
        print("✅ Factory reset completed.")

    default:
        print("Unknown command: '\(command)'. Run 'aula-cli help' for options.")
        exit(1)
    }
} catch {
    print("❌ Error: \(error.localizedDescription)")
    exit(1)
}
