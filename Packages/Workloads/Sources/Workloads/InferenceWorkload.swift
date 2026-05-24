import CaliperCore
import Telemetry
import Validators
import Foundation

public struct InferenceWorkload: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var prompt: String
    public var maxTokens: Int
    public var expectedStructuredKeys: Set<String>

    public init(
        id: UUID = UUID(),
        name: String,
        prompt: String,
        maxTokens: Int = 256,
        expectedStructuredKeys: Set<String> = []
    ) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.maxTokens = maxTokens
        self.expectedStructuredKeys = expectedStructuredKeys
    }
}

public actor WorkloadRunner {
    private let session: CaliperSession
    private let collector: TelemetryCollector

    public init(session: CaliperSession, collector: TelemetryCollector) {
        self.session = session
        self.collector = collector
    }

    public func startCollecting() {
        Task {
            for await event in await session.events {
                await collector.ingest(event)
            }
        }
    }

    @discardableResult
    public func run(_ workload: InferenceWorkload) async throws -> InferenceResult {
        let request = InferenceRequest(
            prompt: workload.prompt,
            maxTokens: workload.maxTokens,
            metadata: ["workload.name": workload.name]
        )

        let result = try await session.run(request)

        if !workload.expectedStructuredKeys.isEmpty {
            let validator = JSONSchemaLiteValidator(requiredTopLevelKeys: workload.expectedStructuredKeys)
            let point = StructuredOutputProbe(validator: validator).point(for: result)
            await collector.record(point)
        }

        return result
    }
}

public extension InferenceWorkload {
    static let smoke = InferenceWorkload(
        name: "Smoke Prompt",
        prompt: "Explain why local inference telemetry matters in one paragraph.",
        maxTokens: 96
    )

    static let structuredJSON = InferenceWorkload(
        name: "Structured JSON",
        prompt: #"Return JSON with keys "summary" and "risk"."#,
        maxTokens: 128,
        expectedStructuredKeys: ["summary", "risk"]
    )
}
