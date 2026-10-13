import AulaKit
import CoreGraphics
import Foundation
import ImageIO

var testsPassed = 0
var testsFailed = 0

func assertTrue(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    if condition {
        testsPassed += 1
        print("  ✅ \(message)")
    } else {
        testsFailed += 1
        print("  ❌ FAIL: \(message) [\(file):\(line)]")
    }
}

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String, file: String = #file, line: Int = #line) {
    if a == b {
        testsPassed += 1
        print("  ✅ \(message)")
    } else {
        testsFailed += 1
        print("  ❌ FAIL: \(message) - Expected '\(b)', got '\(a)' [\(file):\(line)]")
    }
}

print("========================================")
print("🧪 Running AulaKit Test Suite...")
print("========================================")

// TEST 1: DisplayEncoder RGB565 and dimensions
print("\n[Suite 1: DisplayEncoder]")
do {
    let width = AulaConstants.displayWidth   // 240
    let height = AulaConstants.displayHeight // 135
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    // Magenta: R=255, G=0, B=255
    context.setFillColor(red: 1, green: 0, blue: 1, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let cgImage = context.makeImage()!

    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data as CFMutableData, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, cgImage, nil)
    CGImageDestinationFinalize(destination)

    let encoded = try DisplayEncoder.encodeImage(data: data as Data, fitMode: .contain)

    assertEqual(encoded.frameCount, 1, "Single frame decoded correctly")
    assertEqual(encoded.chunkCount, 16, "16 4KB chunks generated for 240x135 frame")
    assertEqual(encoded.data.count, 16 * 4096, "Data buffer size matches 16 * 4096 bytes")
    assertEqual(encoded.data[0], 1, "Header byte[0] stores frame count = 1")
    assertTrue(encoded.data[1] > 0, "Header byte[1] stores positive frame delay")

    // RGB565 Little-Endian for Magenta: 0xF81F -> 0x1F, 0xF8
    let low = encoded.data[AulaConstants.headerLength]
    let high = encoded.data[AulaConstants.headerLength + 1]
    let pixelValue = UInt16(low) | (UInt16(high) << 8)
    assertEqual(pixelValue, 0xF81F, "Magenta pixel encoded to 0xF81F (RGB565)")
} catch {
    testsFailed += 1
    print("  ❌ DisplayEncoder threw error: \(error)")
}

// TEST 2: KeyRemapTable Buffer Structure & Mac Layout Swapping
print("\n[Suite 2: KeyRemapTable & Mac Layout]")
do {
    var table = KeyRemapTable(layer: .normal, macLayoutEnabled: true)
    let buffer = table.buildBuffer()

    assertEqual(buffer.count, 576, "Remap table is exactly 576 bytes")
    assertEqual(buffer[574], 0xAA, "Trailer byte 574 is 0xAA (little-endian 0x55AA)")
    assertEqual(buffer[575], 0x55, "Trailer byte 575 is 0x55")

    // KeyIndex 92 = LWin -> mapped to Left Option (Modifier bit 0x04)
    let lwinOffset = 92 * 4
    assertEqual(buffer[lwinOffset + 0], 0x02, "LWin action type is Key Combination (0x02)")
    assertEqual(buffer[lwinOffset + 1], 0x04, "LWin mapped to Left Option modifier (0x04)")

    // KeyIndex 93 = LAlt -> mapped to Left Command (Modifier bit 0x08)
    let laltOffset = 93 * 4
    assertEqual(buffer[laltOffset + 0], 0x02, "LAlt action type is Key Combination (0x02)")
    assertEqual(buffer[laltOffset + 1], 0x08, "LAlt mapped to Left Command modifier (0x08)")

    // Custom remap test: CapsLock (keyIndex 55) -> Ctrl (0x01)
    table.setAction(.key(modifiers: 0x01, scancode: 0x00), for: 55)
    let buffer2 = table.buildBuffer()
    let capsOffset = 55 * 4
    assertEqual(buffer2[capsOffset + 0], 0x02, "CapsLock action type is 0x02")
    assertEqual(buffer2[capsOffset + 1], 0x01, "CapsLock modifier is Left Ctrl (0x01)")
}

// TEST 3: LightingController & Per-Key RGB Matrix
print("\n[Suite 3: Lighting & Per-Key Matrix]")
do {
    assertEqual(LightingController.presets.count, 20, "20 lighting presets registered")
    assertEqual(LightingController.preset(for: 0)?.name, "LED Off", "Preset 0 is LED Off")
    assertEqual(LightingController.preset(for: 11)?.name, "Rolling", "Preset 11 is Rolling")

    var matrix = PerKeyRGBMatrix()
    matrix.setColor(KeyRGBColor(red: 255, green: 0, blue: 0), for: 1) // Esc = Red
    matrix.setColor(KeyRGBColor(red: 0, green: 0, blue: 255), for: 95) // Space = Blue
    let payload = matrix.buildPayload()

    assertEqual(payload.count, 576, "Per-key payload is 576 bytes")
    assertEqual(payload[4], 1, "Esc slot index is 1")
    assertEqual(payload[5], 255, "Esc Red is 255")
    assertEqual(payload[6], 0, "Esc Green is 0")
    assertEqual(payload[7], 0, "Esc Blue is 0")

    let spaceOffset = 95 * 4
    assertEqual(payload[spaceOffset + 0], 95, "Space slot index is 95")
    assertEqual(payload[spaceOffset + 3], 255, "Space Blue is 255")
    assertEqual(payload[574], 0xAA, "Matrix trailer is 0xAA")
    assertEqual(payload[575], 0x55, "Matrix trailer is 0x55")
}

// TEST 4: Profile Encoding & Decoding
print("\n[Suite 4: KeyboardProfile Serialization]")
do {
    let profile = KeyboardProfile(
        name: "Test Coding Profile",
        rgbMode: 7,
        rgbBrightness: 3,
        rgbSpeed: 2,
        rgbDirection: 1,
        rgbColorful: false,
        rgbHexColor: "#00EEDD",
        macLayoutEnabled: true,
        responseLevel: 2,
        sleepTime: 3
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(profile)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(KeyboardProfile.self, from: data)

    assertEqual(decoded.name, "Test Coding Profile", "Profile name roundtripped")
    assertEqual(decoded.rgbMode, 7, "RGB Mode 7 roundtripped")
    assertEqual(decoded.rgbHexColor, "#00EEDD", "Hex color roundtripped")
    assertTrue(decoded.macLayoutEnabled, "Mac Layout flag preserved")
    assertEqual(decoded.responseLevel, 2, "Debounce response level preserved")
} catch {
    testsFailed += 1
    print("  ❌ Profile test threw: \(error)")
}

// TEST 5: MacroEngine Binary Serialization
print("\n[Suite 5: MacroEngine Serialization]")
do {
    let macro = KeyboardMacro(name: "Test Combo", events: [
        MacroEvent(type: .keyDown, value: 0x04), // Key A down
        MacroEvent(type: .delay, delayMs: 100),
        MacroEvent(type: .keyUp, value: 0x04)   // Key A up
    ])

    let binary = try MacroEngine.serializeMacros([macro])
    assertTrue(binary.count >= 400, "Macro buffer has at least 400 bytes header")
    assertEqual(binary.count % 64, 0, "Macro buffer is padded to multiple of 64 bytes")
    assertEqual(binary[binary.count - 2], 0xAA, "Macro trailer byte 1 is 0xAA")
    assertEqual(binary[binary.count - 1], 0x55, "Macro trailer byte 2 is 0x55")
    assertEqual(binary[0], 0x90, "First macro offset low byte is 400 (0x0190)")
    assertEqual(binary[1], 0x01, "First macro offset high byte is 0x01")
} catch {
    testsFailed += 1
    print("  ❌ MacroEngine test threw: \(error)")
}

// TEST 6: ScreenGalleryManager
print("\n[Suite 6: ScreenGalleryManager]")
do {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("AulaGalleryTest_\(UUID().uuidString)")
    let manager = ScreenGalleryManager(customBaseDirectory: tempDir)

    // Create a 240x135 test image
    let width = AulaConstants.displayWidth
    let height = AulaConstants.displayHeight
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(red: 0, green: 1, blue: 0, alpha: 1) // Green
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let cgImage = context.makeImage()!

    let imgData = NSMutableData()
    let destination = CGImageDestinationCreateWithData(imgData as CFMutableData, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, cgImage, nil)
    CGImageDestinationFinalize(destination)

    let item = try manager.addItem(data: imgData as Data, fileExtension: "png", title: "Test Green Screen")
    assertEqual(item.title, "Test Green Screen", "Gallery item title stored correctly")
    assertEqual(item.frameCount, 1, "Gallery item frame count is 1")
    assertEqual(item.chunkCount, 16, "Gallery item chunk count is 16")

    let loaded = manager.loadItems()
    assertEqual(loaded.count, 1, "Gallery contains 1 item")
    assertEqual(loaded.first?.id, item.id, "Gallery item ID matches")

    let stream = try manager.getStream(for: item)
    assertEqual(stream.count, 16 * 4096, "Pre-encoded cached stream retrieved with exact 16*4096 bytes")

    try manager.setActive(id: item.id)
    let updated = manager.loadItems().first
    assertTrue(updated?.isActive == true, "Gallery item marked active")

    try manager.removeItem(id: item.id)
    assertEqual(manager.loadItems().count, 0, "Gallery item removed successfully")

    try? FileManager.default.removeItem(at: tempDir)
} catch {
    testsFailed += 1
    print("  ❌ ScreenGalleryManager test threw: \(error)")
}

print("\n========================================")
print("📊 Results: \(testsPassed) passed, \(testsFailed) failed")
print("========================================")

if testsFailed > 0 {
    exit(1)
} else {
    exit(0)
}
