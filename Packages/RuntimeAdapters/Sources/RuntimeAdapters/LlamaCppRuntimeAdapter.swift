import CaliperCore
import Foundation

public actor LlamaCppRuntimeAdapter: InferenceRuntime {
    public nonisolated let runtimeName = "llama.cpp"
    private var metadata: ModelMetadata?
    private let tokenProvider: @Sendable (InferenceRequest) async throws -> [String]

    public var modelMetadata: ModelMetadata? {
        metadata
    }

    public init(
        modelIdentifier: String,
        family: String = "llama",
        parameterCount: String? = nil,
        quantization: String? = nil,
        contextLength: Int? = nil,
        tokenProvider: @escaping @Sendable (InferenceRequest) async throws -> [String]
    ) {
        self.metadata = ModelMetadata(
            identifier: modelIdentifier,
            family: family,
            parameterCount: parameterCount,
            quantization: quantization,
            contextLength: contextLength,
            runtime: runtimeName
        )
        self.tokenProvider = tokenProvider
    }

    public func loadModel() async throws -> ModelMetadata {
        guard let metadata else {
            throw CaliperError.runtimeUnavailable("No model metadata was configured.")
        }
        return metadata
    }

    public func run(_ request: InferenceRequest) async throws -> AsyncThrowingStream<TokenEvent, Error> {
        let tokens = try await tokenProvider(request)

        return AsyncThrowingStream { continuation in
            Task {
                for (index, token) in tokens.prefix(request.maxTokens).enumerated() {
                    continuation.yield(
                        TokenEvent(
                            requestID: request.id,
                            index: index,
                            text: token,
                            timestamp: Date()
                        )
                    )
                    try? await Task.sleep(nanoseconds: 18_000_000)
                }
                continuation.finish()
            }
        }
    }
}

public actor SimulatedLlamaRuntime: InferenceRuntime {
    public nonisolated let runtimeName = "llama.cpp.simulated"
    private let metadataValue: ModelMetadata

    public var modelMetadata: ModelMetadata? {
        metadataValue
    }

    public init(
        modelIdentifier: String = "model.gguf",
        quantization: String = "Q4_0"
    ) {
        self.metadataValue = ModelMetadata(
            identifier: modelIdentifier,
            family: "llama",
            parameterCount: "1.1B",
            quantization: quantization,
            contextLength: 2048,
            runtime: runtimeName
        )
    }

    public func loadModel() async throws -> ModelMetadata {
        try await Task.sleep(nanoseconds: 250_000_000)
        return metadataValue
    }

    public func run(_ request: InferenceRequest) async throws -> AsyncThrowingStream<TokenEvent, Error> {
        let words = """
        Caliper observes local inference behavior by recording lifecycle spans, first-token latency, sustained throughput, memory growth, thermal state, and structured-output reliability.
        """
        .split(separator: " ")
        .map { String($0) + " " }

        return AsyncThrowingStream { continuation in
            Task {
                for (index, word) in words.prefix(request.maxTokens).enumerated() {
                    continuation.yield(TokenEvent(requestID: request.id, index: index, text: word))
                    try? await Task.sleep(nanoseconds: 45_000_000)
                }
                continuation.finish()
            }
        }
    }
}
