import CoreGraphics
import Foundation
import ImageIO

public struct ScreenGalleryItem: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var title: String
    public let createdAt: Date
    public let frameCount: Int
    public let chunkCount: Int
    public let totalBytes: Int
    public let fitMode: String
    public var isActive: Bool
    public let originalFilename: String
    public let cacheFilename: String

    public init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        frameCount: Int,
        chunkCount: Int,
        totalBytes: Int,
        fitMode: String = ScreenFitMode.contain.rawValue,
        isActive: Bool = false,
        originalFilename: String,
        cacheFilename: String
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.frameCount = frameCount
        self.chunkCount = chunkCount
        self.totalBytes = totalBytes
        self.fitMode = fitMode
        self.isActive = isActive
        self.originalFilename = originalFilename
        self.cacheFilename = cacheFilename
    }
}

public final class ScreenGalleryManager: @unchecked Sendable {
    public static let shared = ScreenGalleryManager()

    private let fileManager = FileManager.default
    private let baseDirectory: URL
    private let originalsDirectory: URL
    private let cacheDirectory: URL
    private let indexURL: URL
    private let lock = NSLock()

    public init(customBaseDirectory: URL? = nil) {
        if let customBaseDirectory {
            self.baseDirectory = customBaseDirectory
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.baseDirectory = appSupport.appendingPathComponent("AulaDriver/gallery", isDirectory: true)
        }
        self.originalsDirectory = self.baseDirectory.appendingPathComponent("originals", isDirectory: true)
        self.cacheDirectory = self.baseDirectory.appendingPathComponent("cache", isDirectory: true)
        self.indexURL = self.baseDirectory.appendingPathComponent("gallery.json")

        setupDirectories()
    }

    private func setupDirectories() {
        try? fileManager.createDirectory(at: originalsDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    public func loadItems() -> [ScreenGalleryItem] {
        lock.lock()
        defer { lock.unlock() }

        guard fileManager.fileExists(atPath: indexURL.path),
              let data = try? Data(contentsOf: indexURL),
              let items = try? JSONDecoder().decode([ScreenGalleryItem].self, from: data) else {
            return []
        }
        return items
    }

    private func saveItems(_ items: [ScreenGalleryItem]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(items)
        try data.write(to: indexURL, options: .atomic)
    }

    @discardableResult
    public func addItem(
        from sourceURL: URL,
        title: String? = nil,
        fitMode: ScreenFitMode = .contain
    ) throws -> ScreenGalleryItem {
        let data = try Data(contentsOf: sourceURL)
        let ext = sourceURL.pathExtension.isEmpty ? "gif" : sourceURL.pathExtension
        let itemTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? title!
            : sourceURL.deletingPathExtension().lastPathComponent

        return try addItem(data: data, fileExtension: ext, title: itemTitle, fitMode: fitMode)
    }

    @discardableResult
    public func addItem(
        data: Data,
        fileExtension: String = "gif",
        title: String,
        fitMode: ScreenFitMode = .contain
    ) throws -> ScreenGalleryItem {
        lock.lock()
        defer { lock.unlock() }

        setupDirectories()

        // 1. Pre-encode to 240x135 RGB565 stream
        let encoded = try DisplayEncoder.encodeImage(data: data, fitMode: fitMode)

        // 2. Prepare file identifiers
        let id = UUID()
        let origFilename = "\(id.uuidString).\(fileExtension)"
        let binFilename = "\(id.uuidString).bin"

        let origDest = originalsDirectory.appendingPathComponent(origFilename)
        let binDest = cacheDirectory.appendingPathComponent(binFilename)

        // 3. Persist original and pre-encoded cache
        try data.write(to: origDest, options: .atomic)
        try encoded.data.write(to: binDest, options: .atomic)

        // 4. Create record
        let item = ScreenGalleryItem(
            id: id,
            title: title,
            createdAt: Date(),
            frameCount: encoded.frameCount,
            chunkCount: encoded.chunkCount,
            totalBytes: encoded.data.count,
            fitMode: fitMode.rawValue,
            isActive: false,
            originalFilename: origFilename,
            cacheFilename: binFilename
        )

        var items = loadItemsInternal()
        items.insert(item, at: 0)
        try saveItems(items)

        return item
    }

    public func removeItem(id: UUID) throws {
        lock.lock()
        defer { lock.unlock() }

        var items = loadItemsInternal()
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let item = items.remove(at: index)

        // Remove disk files
        let origDest = originalsDirectory.appendingPathComponent(item.originalFilename)
        let binDest = cacheDirectory.appendingPathComponent(item.cacheFilename)
        try? fileManager.removeItem(at: origDest)
        try? fileManager.removeItem(at: binDest)

        try saveItems(items)
    }

    public func setActive(id: UUID) throws {
        lock.lock()
        defer { lock.unlock() }

        var items = loadItemsInternal()
        for i in 0..<items.count {
            items[i].isActive = (items[i].id == id)
        }
        try saveItems(items)
    }

    public func getStream(for item: ScreenGalleryItem) throws -> Data {
        let binPath = cacheDirectory.appendingPathComponent(item.cacheFilename)
        guard fileManager.fileExists(atPath: binPath.path) else {
            throw AulaError.imageLoadFailed("Cached screen stream missing for \(item.title)")
        }
        return try Data(contentsOf: binPath)
    }

    public func getOriginalURL(for item: ScreenGalleryItem) -> URL {
        originalsDirectory.appendingPathComponent(item.originalFilename)
    }

    private func loadItemsInternal() -> [ScreenGalleryItem] {
        guard fileManager.fileExists(atPath: indexURL.path),
              let data = try? Data(contentsOf: indexURL),
              let items = try? JSONDecoder().decode([ScreenGalleryItem].self, from: data) else {
            return []
        }
        return items
    }
}
