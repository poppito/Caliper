import CaliperCore
import Foundation

public protocol TelemetryProbe: Sendable {
    var name: String { get }
    mutating func handle(_ event: InferenceLifecycleEvent) async -> [TelemetryPoint]
}

public actor TelemetryCollector {
    private var probes: [any TelemetryProbe]
    private var points: [TelemetryPoint] = []
    private var spans: [UUID: CaliperSpan] = [:]
    private let continuation: AsyncStream<TelemetrySnapshot>.Continuation

    public let snapshots: AsyncStream<TelemetrySnapshot>

    public init(probes: [any TelemetryProbe] = TelemetryCollector.defaultProbes()) {
        self.probes = probes

        var continuation: AsyncStream<TelemetrySnapshot>.Continuation!
        self.snapshots = AsyncStream { streamContinuation in
            continuation = streamContinuation
        }
        self.continuation = continuation
    }

    public static func defaultProbes() -> [any TelemetryProbe] {
        [
            LatencyProbe(),
            TokenThroughputProbe(),
            ThermalProbe(),
            MemoryProbe(),
            BatteryProbe()
        ]
    }

    public func ingest(_ event: InferenceLifecycleEvent) async {
        updateSpan(for: event)

        for index in probes.indices {
            let newPoints = await probes[index].handle(event)
            points.append(contentsOf: newPoints)
        }

        continuation.yield(snapshot)
    }

    public func record(_ point: TelemetryPoint) {
        points.append(point)
        continuation.yield(snapshot)
    }

    public var snapshot: TelemetrySnapshot {
        TelemetrySnapshot(
            points: points,
            spans: Array(spans.values).sorted { $0.start < $1.start },
            updatedAt: Date()
        )
    }

    private func updateSpan(for event: InferenceLifecycleEvent) {
        switch event {
        case .inferenceStarted(let request, let timestamp):
            spans[request.id] = CaliperSpan(
                id: request.id,
                name: "inference",
                start: timestamp,
                attributes: [
                    "caliper.request_id": request.id.uuidString,
                    "llm.prompt.length": "\(request.prompt.count)",
                    "llm.max_tokens": "\(request.maxTokens)"
                ]
            )
        case .tokenProduced(let token):
            spans[token.requestID]?.events.append("token.\(token.index)")
        case .inferenceCompleted(let result, let timestamp):
            spans[result.requestID]?.end = timestamp
            spans[result.requestID]?.attributes["llm.output.tokens"] = "\(result.tokenCount)"
            if let finishReason = result.finishReason {
                spans[result.requestID]?.attributes["llm.finish_reason"] = finishReason
            }
        case .inferenceFailed(let requestID, let message, let timestamp):
            spans[requestID]?.end = timestamp
            spans[requestID]?.attributes["error"] = "true"
            spans[requestID]?.attributes["error.message"] = message
        case .modelLoadStarted, .modelLoaded:
            break
        }
    }

    deinit {
        continuation.finish()
    }
}
