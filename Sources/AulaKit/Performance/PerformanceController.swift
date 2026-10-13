import Foundation

public struct KeyResponseLevel: Identifiable, Hashable, Sendable {
    public let level: Int
    public let title: String
    public let latencyDescription: String

    public var id: Int { level }
}

public struct SleepTimeoutOption: Identifiable, Hashable, Sendable {
    public let value: Int
    public let title: String

    public var id: Int { value }
}

public enum PerformanceCatalog {
    public static let responseLevels: [KeyResponseLevel] = [
        KeyResponseLevel(level: 1, title: "Level 1 (Fastest)", latencyDescription: "5-6 ms latency (Gaming)"),
        KeyResponseLevel(level: 2, title: "Level 2 (Balanced)", latencyDescription: "7-9 ms latency"),
        KeyResponseLevel(level: 3, title: "Level 3 (Stable)", latencyDescription: "10-12 ms latency"),
        KeyResponseLevel(level: 4, title: "Level 4 (Conservative)", latencyDescription: "15-17 ms latency"),
        KeyResponseLevel(level: 5, title: "Level 5 (Max Stability)", latencyDescription: "19-21 ms debounce")
    ]

    public static let sleepOptions: [SleepTimeoutOption] = [
        SleepTimeoutOption(value: 0, title: "Never Sleep"),
        SleepTimeoutOption(value: 1, title: "1 Minute"),
        SleepTimeoutOption(value: 2, title: "5 Minutes"),
        SleepTimeoutOption(value: 3, title: "30 Minutes")
    ]
}
