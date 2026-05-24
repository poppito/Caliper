import Foundation

public actor CaliperSession {
    public let runtime: any InferenceRuntime
    private let eventContinuation: AsyncStream<InferenceLifecycleEvent>.Continuation

    public let events: AsyncStream<InferenceLifecycleEvent>
    private var model: ModelMetadata?

    public init(runtime: any InferenceRuntime) {
        self.runtime = runtime

        var continuation: AsyncStream<InferenceLifecycleEvent>.Continuation!
        self.events = AsyncStream { streamContinuation in
            continuation = streamContinuation
        }
        self.eventContinuation = continuation
    }

    public func loadModel() async throws -> ModelMetadata {
        eventContinuation.yield(.modelLoadStarted(timestamp: Date()))
        let metadata = try await runtime.loadModel()
        model = metadata
        eventContinuation.yield(.modelLoaded(metadata: metadata, timestamp: Date()))
        return metadata
    }

    @discardableResult
    public func run(_ request: InferenceRequest) async throws -> InferenceResult {
        if model == nil {
            _ = try await loadModel()
        }

        eventContinuation.yield(.inferenceStarted(request: request, timestamp: Date()))

        do {
            let stream = try await runtime.run(request)
            var output = ""
            var tokenCount = 0

            for try await token in stream {
                output += token.text
                tokenCount += 1
                eventContinuation.yield(.tokenProduced(token))
            }

            let result = InferenceResult(
                requestID: request.id,
                output: output,
                tokenCount: tokenCount,
                finishReason: "completed"
            )
            eventContinuation.yield(.inferenceCompleted(result: result, timestamp: Date()))
            return result
        } catch {
            eventContinuation.yield(
                .inferenceFailed(
                    requestID: request.id,
                    message: error.localizedDescription,
                    timestamp: Date()
                )
            )
            throw error
        }
    }

    deinit {
        eventContinuation.finish()
    }
}
