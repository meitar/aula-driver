import Foundation

public enum ScreenFitMode: String, CaseIterable, Identifiable, Sendable {
    case contain = "contain"
    case cover = "cover"
    case stretch = "stretch"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .contain: return "Fit (Aspect)"
        case .cover: return "Fill (Crop)"
        case .stretch: return "Stretch"
        }
    }
}

public struct EncodedDisplayStream: Sendable {
    public let data: Data
    public let frameCount: Int
    public let chunkCount: Int

    public init(data: Data, frameCount: Int, chunkCount: Int) {
        self.data = data
        self.frameCount = frameCount
        self.chunkCount = chunkCount
    }
}
