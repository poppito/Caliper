import Foundation

public struct ModelMetadata: Codable, Equatable, Sendable {
    public var identifier: String
    public var family: String
    public var parameterCount: String?
    public var quantization: String?
    public var contextLength: Int?
    public var runtime: String

    public init(
        identifier: String,
        family: String,
        parameterCount: String? = nil,
        quantization: String? = nil,
        contextLength: Int? = nil,
        runtime: String
    ) {
        self.identifier = identifier
        self.family = family
        self.parameterCount = parameterCount
        self.quantization = quantization
        self.contextLength = contextLength
        self.runtime = runtime
    }
}

public struct DeviceMetadata: Codable, Equatable, Sendable {
    public var name: String
    public var systemName: String
    public var systemVersion: String
    public var processorCount: Int
    public var physicalMemoryBytes: UInt64

    public init(
        name: String,
        systemName: String,
        systemVersion: String,
        processorCount: Int = ProcessInfo.processInfo.processorCount,
        physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) {
        self.name = name
        self.systemName = systemName
        self.systemVersion = systemVersion
        self.processorCount = processorCount
        self.physicalMemoryBytes = physicalMemoryBytes
    }
}

public struct InferenceRequest: Codable, Equatable, Sendable {
    public var id: UUID
    public var prompt: String
    public var maxTokens: Int
    public var metadata: [String: String]

    public init(
        id: UUID = UUID(),
        prompt: String,
        maxTokens: Int = 256,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.prompt = prompt
        self.maxTokens = maxTokens
        self.metadata = metadata
    }
}

public struct InferenceResult: Codable, Equatable, Sendable {
    public var requestID: UUID
    public var output: String
    public var tokenCount: Int
    public var finishReason: String?

    public init(
        requestID: UUID,
        output: String,
        tokenCount: Int,
        finishReason: String? = nil
    ) {
        self.requestID = requestID
        self.output = output
        self.tokenCount = tokenCount
        self.finishReason = finishReason
    }
}

public struct TokenEvent: Codable, Equatable, Sendable {
    public var requestID: UUID
    public var index: Int
    public var text: String
    public var timestamp: Date

    public init(
        requestID: UUID,
        index: Int,
        text: String,
        timestamp: Date = Date()
    ) {
        self.requestID = requestID
        self.index = index
        self.text = text
        self.timestamp = timestamp
    }
}
