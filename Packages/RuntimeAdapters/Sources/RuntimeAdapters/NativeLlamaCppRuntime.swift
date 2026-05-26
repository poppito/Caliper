import CaliperCore
import Foundation

#if canImport(llama)
import llama

public actor NativeLlamaCppRuntime: InferenceRuntime {
    public nonisolated let runtimeName = "llama.cpp"
    public nonisolated let modelPath: String

    private let configuration: LlamaCppBridgeConfiguration
    private let modelIdentifier: String
    private let family: String
    private let quantization: String?
    private var metadata: ModelMetadata?
    private var model: OpaquePointer?
    private var context: OpaquePointer?
    private var backendInitialized = false

    public var modelMetadata: ModelMetadata? {
        metadata
    }

    public init(
        modelURL: URL,
        family: String = "llama",
        quantization: String? = nil,
        contextLength: Int = 2048,
        gpuLayerCount: Int = 0,
        threadCount: Int = max(1, ProcessInfo.processInfo.processorCount - 1)
    ) {
        self.modelPath = modelURL.path
        self.configuration = LlamaCppBridgeConfiguration(
            modelPath: modelURL.path,
            contextLength: contextLength,
            gpuLayerCount: gpuLayerCount,
            threadCount: threadCount
        )
        self.modelIdentifier = modelURL.lastPathComponent
        self.family = family
        self.quantization = quantization
    }

    public func loadModel() async throws -> ModelMetadata {
        if let metadata {
            return metadata
        }

        guard FileManager.default.fileExists(atPath: configuration.modelPath) else {
            throw CaliperError.runtimeUnavailable("Model file not found at \(configuration.modelPath)")
        }

        llama_backend_init()
        backendInitialized = true

        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = Int32(configuration.gpuLayerCount)

        guard let loadedModel = llama_load_model_from_file(configuration.modelPath, modelParams) else {
            throw CaliperError.runtimeUnavailable("llama_load_model_from_file failed")
        }

        var contextParams = llama_context_default_params()
        contextParams.n_ctx = UInt32(configuration.contextLength)
        contextParams.n_threads = Int32(configuration.threadCount)
        contextParams.n_threads_batch = Int32(configuration.threadCount)

        guard let loadedContext = llama_new_context_with_model(loadedModel, contextParams) else {
            llama_free_model(loadedModel)
            throw CaliperError.runtimeUnavailable("llama_new_context_with_model failed")
        }

        model = loadedModel
        context = loadedContext

        let resolved = ModelMetadata(
            identifier: modelIdentifier,
            family: family,
            parameterCount: nil,
            quantization: quantization,
            contextLength: configuration.contextLength,
            runtime: runtimeName
        )
        metadata = resolved
        return resolved
    }

    public func run(_ request: InferenceRequest) async throws -> AsyncThrowingStream<TokenEvent, Error> {
        _ = try await loadModel()

        guard let model, let context else {
            throw CaliperError.modelNotLoaded
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    try await self.generate(
                        request: request,
                        model: model,
                        context: context,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    deinit {
        if let context {
            llama_free(context)
        }
        if let model {
            llama_free_model(model)
        }
        if backendInitialized {
            llama_backend_free()
        }
    }

    private func generate(
        request: InferenceRequest,
        model: OpaquePointer,
        context: OpaquePointer,
        continuation: AsyncThrowingStream<TokenEvent, Error>.Continuation
    ) async throws {
        llama_memory_clear(llama_get_memory(context), true)

        let prompt = promptText(for: request)
        guard let promptCString = prompt.cString(using: .utf8) else {
            throw CaliperError.invalidOutput("Prompt could not be encoded as UTF-8")
        }

        guard let vocab = llama_model_get_vocab(model) else {
            throw CaliperError.runtimeUnavailable("llama_model_get_vocab returned nil")
        }

        let promptTokenCount = -llama_tokenize(
            vocab,
            promptCString,
            Int32(strlen(promptCString)),
            nil,
            0,
            true,
            false
        )

        guard promptTokenCount > 0 else {
            throw CaliperError.runtimeUnavailable("Prompt tokenization failed")
        }

        var promptTokens = [llama_token](repeating: 0, count: Int(promptTokenCount))
        let tokenizeResult = llama_tokenize(
            vocab,
            promptCString,
            Int32(strlen(promptCString)),
            &promptTokens,
            Int32(promptTokens.count),
            true,
            false
        )

        guard tokenizeResult >= 0 else {
            throw CaliperError.runtimeUnavailable("Prompt tokenization returned an error")
        }

        var batch = llama_batch_init(Int32(promptTokens.count + request.maxTokens + 8), 0, 1)
        defer { llama_batch_free(batch) }

        for (index, token) in promptTokens.enumerated() {
            batch.token[index] = token
            batch.pos[index] = Int32(index)
            batch.seq_id[index]![0] = 0
            batch.n_seq_id[index] = 1
            batch.logits[index] = index == promptTokens.count - 1 ? 1 : 0
        }
        batch.n_tokens = Int32(promptTokens.count)

        guard llama_decode(context, batch) == 0 else {
            throw CaliperError.runtimeUnavailable("Initial decode failed")
        }

        let eosToken = llama_vocab_eos(vocab)

        for index in 0..<request.maxTokens {
            guard let logits = llama_get_logits_ith(context, batch.n_tokens - 1) else {
                throw CaliperError.runtimeUnavailable("Could not read logits")
            }

            let nextToken = greedyToken(from: logits, vocab: vocab)
            if nextToken == eosToken {
                break
            }

            let piece = piece(for: nextToken, vocab: vocab)
            if !piece.isEmpty {
                continuation.yield(
                    TokenEvent(
                        requestID: request.id,
                        index: index,
                        text: piece,
                        timestamp: Date()
                    )
                )
            }

            batch.n_tokens = 1
            batch.token[0] = nextToken
            batch.pos[0] = Int32(promptTokens.count + index)
            batch.seq_id[0]![0] = 0
            batch.n_seq_id[0] = 1
            batch.logits[0] = 1

            guard llama_decode(context, batch) == 0 else {
                throw CaliperError.runtimeUnavailable("Token decode failed")
            }
        }
    }

    private func promptText(for request: InferenceRequest) -> String {
        var prompt = "You are a concise, helpful local assistant on iPhone.\n\n"
        if !request.metadata.isEmpty {
            prompt += request.metadata
                .sorted { $0.key < $1.key }
                .map { "\($0.key): \($0.value)" }
                .joined(separator: "\n")
            prompt += "\n\n"
        }
        prompt += "User: \(request.prompt)\nAssistant:"
        return prompt
    }

    private func greedyToken(from logits: UnsafeMutablePointer<Float>, vocab: OpaquePointer) -> llama_token {
        let vocabSize = Int(llama_vocab_n_tokens(vocab))
        var bestToken: llama_token = 0
        var bestLogit = -Float.greatestFiniteMagnitude

        for index in 0..<vocabSize {
            let value = logits[index]
            if value > bestLogit {
                bestLogit = value
                bestToken = llama_token(index)
            }
        }

        return bestToken
    }

    private func piece(for token: llama_token, vocab: OpaquePointer) -> String {
        var buffer = [CChar](repeating: 0, count: 256)
        let length = llama_token_to_piece(
            vocab,
            token,
            &buffer,
            Int32(buffer.count),
            0,
            false
        )

        guard length > 0 else { return "" }

        let bytes = buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }
}

#else

public actor NativeLlamaCppRuntime: InferenceRuntime {
    public nonisolated let runtimeName = "llama.cpp"
    public nonisolated let modelPath: String
    public var modelMetadata: ModelMetadata?

    public init(
        modelURL: URL,
        family: String = "llama",
        quantization: String? = nil,
        contextLength: Int = 2048,
        gpuLayerCount: Int = 0,
        threadCount: Int = max(1, ProcessInfo.processInfo.processorCount - 1)
    ) {
        self.modelPath = modelURL.path
        _ = modelURL
        _ = family
        _ = quantization
        _ = contextLength
        _ = gpuLayerCount
        _ = threadCount
    }

    public func loadModel() async throws -> ModelMetadata {
        throw CaliperError.runtimeUnavailable("llama.cpp module is not available in this build")
    }

    public func run(_ request: InferenceRequest) async throws -> AsyncThrowingStream<TokenEvent, Error> {
        _ = request
        throw CaliperError.runtimeUnavailable("llama.cpp module is not available in this build")
    }
}

#endif
