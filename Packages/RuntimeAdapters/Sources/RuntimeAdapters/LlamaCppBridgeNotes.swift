import Foundation

public struct LlamaCppBridgeConfiguration: Codable, Equatable, Sendable {
    public var modelPath: String
    public var contextLength: Int
    public var gpuLayerCount: Int
    public var threadCount: Int

    public init(
        modelPath: String,
        contextLength: Int = 2048,
        gpuLayerCount: Int = 0,
        threadCount: Int = max(1, ProcessInfo.processInfo.processorCount - 1)
    ) {
        self.modelPath = modelPath
        self.contextLength = contextLength
        self.gpuLayerCount = gpuLayerCount
        self.threadCount = threadCount
    }
}
