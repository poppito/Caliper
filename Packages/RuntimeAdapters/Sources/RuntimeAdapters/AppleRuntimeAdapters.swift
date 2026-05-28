import CaliperCore
import Foundation

#if canImport(CoreML)
import CoreML
#endif

#if canImport(FoundationModels)
import FoundationModels
#endif

#if canImport(MLX)
import MLX
#endif

public enum AppleInferenceRuntimeKind: String, Codable, CaseIterable, Sendable {
    case automatic
    case llamaCpp
    case mlx
    case coreML
    case foundationModels
    case simulated
}

public actor MLXRuntimeAdapter: InferenceRuntime {
    public nonisolated let runtimeName = "MLX"
    public nonisolated let modelIdentifier: String
    public var modelMetadata: ModelMetadata?

    public init(modelIdentifier: String = "mlx-model") {
        self.modelIdentifier = modelIdentifier
    }

    public func loadModel() async throws -> ModelMetadata {
        #if canImport(MLX)
        throw CaliperError.runtimeUnavailable("MLX adapter boundary is present, but model loading is not configured yet.")
        #else
        throw CaliperError.runtimeUnavailable("MLX is not available in this build.")
        #endif
    }

    public func run(_ request: InferenceRequest) async throws -> AsyncThrowingStream<TokenEvent, Error> {
        _ = request
        throw CaliperError.runtimeUnavailable("MLX runtime execution is not configured yet.")
    }
}

public actor CoreMLRuntimeAdapter: InferenceRuntime {
    public nonisolated let runtimeName = "Core ML"
    public nonisolated let modelURL: URL?
    public var modelMetadata: ModelMetadata?

    public init(modelURL: URL? = nil) {
        self.modelURL = modelURL
    }

    public func loadModel() async throws -> ModelMetadata {
        #if canImport(CoreML)
        throw CaliperError.runtimeUnavailable("Core ML adapter boundary is present, but MLModel execution is not configured yet.")
        #else
        throw CaliperError.runtimeUnavailable("Core ML is not available in this build.")
        #endif
    }

    public func run(_ request: InferenceRequest) async throws -> AsyncThrowingStream<TokenEvent, Error> {
        _ = request
        throw CaliperError.runtimeUnavailable("Core ML runtime execution is not configured yet.")
    }
}

public actor FoundationModelsRuntimeAdapter: InferenceRuntime {
    public nonisolated let runtimeName = "Foundation Models"
    public var modelMetadata: ModelMetadata?

    public init() {}

    public func loadModel() async throws -> ModelMetadata {
        #if canImport(FoundationModels)
        throw CaliperError.runtimeUnavailable("Foundation Models adapter boundary is present, but session execution is not configured yet.")
        #else
        throw CaliperError.runtimeUnavailable("Foundation Models is not available in this build.")
        #endif
    }

    public func run(_ request: InferenceRequest) async throws -> AsyncThrowingStream<TokenEvent, Error> {
        _ = request
        throw CaliperError.runtimeUnavailable("Foundation Models runtime execution is not configured yet.")
    }
}
