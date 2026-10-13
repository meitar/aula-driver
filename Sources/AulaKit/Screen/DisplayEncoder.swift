import CoreGraphics
import Foundation
import ImageIO

#if canImport(AppKit)
import AppKit
#endif

public enum DisplayEncoder {
    public static func encodeImage(at url: URL, fitMode: ScreenFitMode = .contain) throws -> EncodedDisplayStream {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw AulaError.imageLoadFailed("Could not open image file at \(url.lastPathComponent)")
        }
        return try encode(source: source, fitMode: fitMode)
    }

    public static func encodeImage(data: Data, fitMode: ScreenFitMode = .contain) throws -> EncodedDisplayStream {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw AulaError.imageLoadFailed("Could not decode image data")
        }
        return try encode(source: source, fitMode: fitMode)
    }

    private static func encode(source: CGImageSource, fitMode: ScreenFitMode) throws -> EncodedDisplayStream {
        let sourceFrameCount = max(CGImageSourceGetCount(source), 1)
        let frameCount = min(sourceFrameCount, AulaConstants.maxFrames)
        let payloadLength = AulaConstants.headerLength + (frameCount * AulaConstants.frameBytes)
        let chunkCount = (payloadLength + AulaConstants.chunkLength - 1) / AulaConstants.chunkLength
        var stream = Data(repeating: 0xFF, count: chunkCount * AulaConstants.chunkLength)

        // Header: byte[0] = frame count, bytes[1..frameCount] = per-frame delay ticks
        stream[0] = UInt8(frameCount)
        for index in 0..<frameCount {
            stream[1 + index] = delayByte(source: source, index: index)
        }

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw AulaError.imageLoadFailed("sRGB color space is unavailable")
        }

        let width = AulaConstants.displayWidth   // 240
        let height = AulaConstants.displayHeight // 135
        let bytesPerRow = width * 4
        var canvas = [UInt8](repeating: 0, count: height * bytesPerRow)

        for frameIndex in 0..<frameCount {
            guard let image = CGImageSourceCreateImageAtIndex(source, frameIndex, nil) else {
                throw AulaError.imageLoadFailed("Failed to render frame \(frameIndex + 1)")
            }

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
                ) else {
                    return
                }

                context.interpolationQuality = .high
                context.setBlendMode(.copy)
                context.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
                context.fill(CGRect(x: 0, y: 0, width: width, height: height))

                context.setBlendMode(.normal)
                context.draw(image, in: drawRect(for: image, fitMode: fitMode, targetWidth: width, targetHeight: height))
            }

            let streamOffset = AulaConstants.headerLength + (frameIndex * AulaConstants.frameBytes)
            encodeRGB565(canvas: canvas, width: width, height: height, into: &stream, at: streamOffset)
        }

        return EncodedDisplayStream(data: stream, frameCount: frameCount, chunkCount: chunkCount)
    }

    private static func delayByte(source: CGImageSource, index: Int) -> UInt8 {
        let fallback = 0.1
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
            let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        else {
            return secondsToDeviceDelay(fallback)
        }

        let unclamped = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber
        let clamped = gifProperties[kCGImagePropertyGIFDelayTime] as? NSNumber
        let seconds = unclamped?.doubleValue ?? clamped?.doubleValue ?? fallback
        return secondsToDeviceDelay(seconds)
    }

    private static func secondsToDeviceDelay(_ seconds: Double) -> UInt8 {
        // Device timer tick unit: centiseconds / 2 (or roughly 500 ticks/sec normalized)
        let normalized = seconds <= 0 ? 0.02 : seconds
        let value = Int((normalized * 50.0).rounded())
        return UInt8(max(1, min(255, value)))
    }

    private static func drawRect(for image: CGImage, fitMode: ScreenFitMode, targetWidth: Int, targetHeight: Int) -> CGRect {
        let target = CGSize(width: targetWidth, height: targetHeight)
        let source = CGSize(width: image.width, height: image.height)

        switch fitMode {
        case .stretch:
            return CGRect(origin: .zero, size: target)
        case .contain, .cover:
            let scaleX = target.width / source.width
            let scaleY = target.height / source.height
            let scale = fitMode == .contain ? min(scaleX, scaleY) : max(scaleX, scaleY)
            let width = source.width * scale
            let height = source.height * scale
            return CGRect(
                x: (target.width - width) / 2.0,
                y: (target.height - height) / 2.0,
                width: width,
                height: height
            )
        }
    }

    private static func encodeRGB565(canvas: [UInt8], width: Int, height: Int, into stream: inout Data, at offset: Int) {
        let totalPixels = width * height
        for pixelIndex in 0..<totalPixels {
            let base = pixelIndex * 4
            let red = UInt16(canvas[base]) >> 3       // 5 bits
            let green = UInt16(canvas[base + 1]) >> 2 // 6 bits
            let blue = UInt16(canvas[base + 2]) >> 3  // 5 bits
            let pixel = (red << 11) | (green << 5) | blue // RGB565 little-endian
            stream[offset + pixelIndex * 2] = UInt8(pixel & 0xFF)
            stream[offset + pixelIndex * 2 + 1] = UInt8(pixel >> 8)
        }
    }
}
