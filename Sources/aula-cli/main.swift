import AulaKit
import Foundation

func printHelp() {
    print("""
    aula-cli: Aula F108 Pro Mechanical Keyboard Control Utility
    
    USAGE:
      aula-cli <command> [options]
      
    COMMANDS:
      info                          Show detected endpoints and device status
      clock sync                    Synchronize keyboard LCD clock to system time
      rgb set [options]             Configure RGB backlighting
                                      --mode <0-19>       Preset effect ID (default: 11)
                                      --brightness <0-5>  Brightness level (default: 5)
                                      --speed <1-5>       Speed level (default: 3)
                                      --direction <0-3>   Direction (0:Right, 1:Down, 2:Left, 3:Up)
                                      --color <#RRGGBB>   Custom color (e.g. "#00FF88")
                                      --colorful          Enable rainbow cycling
      rgb off                       Turn off keyboard backlighting
      rgb list                      List all 20 available lighting preset modes
      screen upload <path> [opts]   Upload image/GIF to keyboard LCD screen (240x135)
                                      --slot <1-255>      Slot number (default: 1)
                                      --fit <fit|fill|stretch>
      remap mac-layout [on|off]     Toggle Mac layout mode (swaps Win and Alt)
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

        default:
            print("Unknown rgb subcommand: \(sub)")
            exit(1)
        }

    case "screen":
        guard args.count > 2, args[1] == "upload" else {
            print("Usage: aula-cli screen upload <file_path> [--slot <1-255>] [--fit <fit|fill|stretch>]")
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
        } else if sub == "reset" {
            print("⌨️  Resetting all key remapping to default...")
            let table = KeyRemapTable()
            try device.applyKeyRemap(layer: .normal, table: table.buildBuffer())
            try device.applyKeyRemap(layer: .fn, table: table.buildBuffer())
            print("✅ Keys reset to default.")
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
