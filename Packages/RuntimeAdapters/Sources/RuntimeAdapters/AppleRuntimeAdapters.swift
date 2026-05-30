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
    private var metadata: ModelMetadata?
    private let tokenProvider: (@Sendable (InferenceRequest) async throws -> [String])?

    public var modelMetadata: ModelMetadata? {
        metadata
    }

    public init(
        modelIdentifier: String = "mlx-model",
        tokenProvider: (@Sendable (InferenceRequest) async throws -> [String])? = nil
    ) {
        self.modelIdentifier = modelIdentifier
        self.tokenProvider = tokenProvider
        self.metadata = ModelMetadata(
            identifier: modelIdentifier,
            family: "mlx",
            runtime: runtimeName
        )
    }

    public func loadModel() async throws -> ModelMetadata {
        guard let metadata else {
            throw CaliperError.runtimeUnavailable("No MLX model metadata was configured.")
        }
        return metadata
    }

    public func run(_ request: InferenceRequest) async throws -> AsyncThrowingStream<TokenEvent, Error> {
        guard let tokenProvider else {
            #if canImport(MLX)
            throw CaliperError.runtimeUnavailable("MLX is available, but no MLX token provider has been configured.")
            #else
            throw CaliperError.runtimeUnavailable("MLX is not available in this build. Provide a tokenProvider or add an MLX runtime package.")
            #endif
        }

        let tokens = try await tokenProvider(request)
        return tokenStream(tokens: tokens, request: request)
    }
}

public actor CoreMLRuntimeAdapter: InferenceRuntime {
    public nonisolated let runtimeName = "Core ML"
    public nonisolated let modelURL: URL?
    public nonisolated let inputName: String
    public nonisolated let outputName: String?
    private let configuration: CoreMLTextModelConfiguration
    private var model: Any?
    private var metadata: ModelMetadata?

    public var modelMetadata: ModelMetadata? {
        metadata
    }

    public init(
        modelURL: URL? = nil,
        inputName: String = "prompt",
        outputName: String? = nil,
        configuration: CoreMLTextModelConfiguration = CoreMLTextModelConfiguration()
    ) {
        self.modelURL = modelURL
        self.inputName = inputName
        self.outputName = outputName
        self.configuration = configuration
    }

    public func loadModel() async throws -> ModelMetadata {
        #if canImport(CoreML)
        if let metadata {
            return metadata
        }

        guard let modelURL else {
            throw CaliperError.runtimeUnavailable("Core ML model URL was not provided.")
        }

        let resolvedURL: URL
        if modelURL.pathExtension == "mlpackage" || modelURL.pathExtension == "mlmodel" {
            resolvedURL = try await MLModel.compileModel(at: modelURL)
        } else {
            resolvedURL = modelURL
        }

        let modelConfiguration = MLModelConfiguration()
        modelConfiguration.computeUnits = configuration.computeUnits
        let loadedModel = try await MLModel.load(contentsOf: resolvedURL, configuration: modelConfiguration)
        self.model = loadedModel

        let resolved = ModelMetadata(
            identifier: modelURL.lastPathComponent,
            family: "coreml",
            contextLength: nil,
            runtime: runtimeName
        )
        metadata = resolved
        return resolved
        #else
        throw CaliperError.runtimeUnavailable("Core ML is not available in this build.")
        #endif
    }

    public func run(_ request: InferenceRequest) async throws -> AsyncThrowingStream<TokenEvent, Error> {
        #if canImport(CoreML)
        _ = try await loadModel()

        guard let loadedModel = model as? MLModel else {
            throw CaliperError.modelNotLoaded
        }

        let input = try MLDictionaryFeatureProvider(dictionary: [
            inputName: MLFeatureValue(string: request.prompt)
        ])
        let output = try await loadedModel.prediction(from: input)
        let text = try Self.textOutput(from: output, preferredName: outputName)
        return tokenStream(tokens: Self.tokenize(text), request: request)
        #else
        _ = request
        throw CaliperError.runtimeUnavailable("Core ML is not available in this build.")
        #endif
    }

    #if canImport(CoreML)
    private static func textOutput(from output: any MLFeatureProvider, preferredName: String?) throws -> String {
        if let preferredName,
           let value = output.featureValue(for: preferredName),
           let text = text(from: value) {
            return text
        }

        for featureName in output.featureNames {
            guard let value = output.featureValue(for: featureName), let text = text(from: value) else {
                continue
            }
            return text
        }

        throw CaliperError.invalidOutput("Core ML output did not contain a string-compatible feature.")
    }

    private static func text(from value: MLFeatureValue) -> String? {
        if value.type == .string {
            return value.stringValue
        }
        if value.type == .dictionary {
            return value.dictionaryValue.description
        }
        if value.type == .multiArray {
            return value.multiArrayValue?.description
        }
        return nil
    }
    #endif
}

public actor FoundationModelsRuntimeAdapter: InferenceRuntime {
    public nonisolated let runtimeName = "Foundation Models"
    private var metadata: ModelMetadata?
    private var session: Any?

    public var modelMetadata: ModelMetadata? {
        metadata
    }

    public init() {}

    public func loadModel() async throws -> ModelMetadata {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) else {
            throw CaliperError.runtimeUnavailable("Foundation Models requires iOS 26, macOS 26, or visionOS 26.")
        }

        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            throw CaliperError.runtimeUnavailable("Foundation Models is unavailable: \(model.availability.caliperDescription)")
        }

        if session == nil {
            session = LanguageModelSession(model: model)
        }

        let resolved = ModelMetadata(
            identifier: "SystemLanguageModel.default",
            family: "foundation-models",
            runtime: runtimeName
        )
        metadata = resolved
        return resolved
        #else
        throw CaliperError.runtimeUnavailable("Foundation Models is not available in this build.")
        #endif
    }

    public func run(_ request: InferenceRequest) async throws -> AsyncThrowingStream<TokenEvent, Error> {
        #if canImport(FoundationModels)
        _ = try await loadModel()

        guard #available(iOS 26.0, macOS 26.0, visionOS 26.0, *),
              let session = session as? LanguageModelSession else {
            throw CaliperError.modelNotLoaded
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let options = GenerationOptions(maximumResponseTokens: request.maxTokens)
                    let stream = session.streamResponse(to: request.prompt, options: options)
                    var previous = ""
                    var index = 0

                    for try await snapshot in stream {
                        let current = snapshot.content
                        let tokenText = current.hasPrefix(previous)
                            ? String(current.dropFirst(previous.count))
                            : current

                        if !tokenText.isEmpty {
                            continuation.yield(
                                TokenEvent(
                                    requestID: request.id,
                                    index: index,
                                    text: tokenText,
                                    timestamp: Date()
                                )
                            )
                            index += 1
                        }

                        previous = current
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
        #else
        _ = request
        throw CaliperError.runtimeUnavailable("Foundation Models is not available in this build.")
        #endif
    }
}

public struct CoreMLTextModelConfiguration: Sendable {
    #if canImport(CoreML)
    public var computeUnits: MLComputeUnits

    public init(computeUnits: MLComputeUnits = .all) {
        self.computeUnits = computeUnits
    }
    #else
    public init() {}
    #endif
}

private func tokenStream(tokens: [String], request: InferenceRequest) -> AsyncThrowingStream<TokenEvent, Error> {
    AsyncThrowingStream { continuation in
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
            }
            continuation.finish()
        }
    }
}

private extension CoreMLRuntimeAdapter {
    static func tokenize(_ text: String) -> [String] {
        let parts = text.split(separator: " ", omittingEmptySubsequences: false)
        guard !parts.isEmpty else {
            return text.isEmpty ? [] : [text]
        }
        return parts.map { String($0) + " " }
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
private extension SystemLanguageModel.Availability {
    var caliperDescription: String {
        switch self {
        case .available:
            return "available"
        case .unavailable(let reason):
            return "unavailable(\(reason))"
        }
    }
}
#endif
