import Foundation

public enum InferenceLifecycleEvent: Codable, Equatable, Sendable {
    case modelLoadStarted(timestamp: Date)
    case modelLoaded(metadata: ModelMetadata, timestamp: Date)
    case inferenceStarted(request: InferenceRequest, timestamp: Date)
    case tokenProduced(TokenEvent)
    case inferenceCompleted(result: InferenceResult, timestamp: Date)
    case inferenceFailed(requestID: UUID, message: String, timestamp: Date)

    public var timestamp: Date {
        switch self {
        case .modelLoadStarted(let timestamp):
            return timestamp
        case .modelLoaded(_, let timestamp):
            return timestamp
        case .inferenceStarted(_, let timestamp):
            return timestamp
        case .tokenProduced(let token):
            return token.timestamp
        case .inferenceCompleted(_, let timestamp):
            return timestamp
        case .inferenceFailed(_, _, let timestamp):
            return timestamp
        }
    }
}

public struct TelemetryPoint: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var value: Double
    public var unit: String
    public var timestamp: Date
    public var attributes: [String: String]

    public init(
        id: UUID = UUID(),
        name: String,
        value: Double,
        unit: String,
        timestamp: Date = Date(),
        attributes: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.unit = unit
        self.timestamp = timestamp
        self.attributes = attributes
    }
}

public struct CaliperSpan: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var start: Date
    public var end: Date?
    public var attributes: [String: String]
    public var events: [String]

    public init(
        id: UUID = UUID(),
        name: String,
        start: Date = Date(),
        end: Date? = nil,
        attributes: [String: String] = [:],
        events: [String] = []
    ) {
        self.id = id
        self.name = name
        self.start = start
        self.end = end
        self.attributes = attributes
        self.events = events
    }
}

public struct TelemetrySnapshot: Codable, Equatable, Sendable {
    public var points: [TelemetryPoint]
    public var spans: [CaliperSpan]
    public var updatedAt: Date

    public init(
        points: [TelemetryPoint] = [],
        spans: [CaliperSpan] = [],
        updatedAt: Date = Date()
    ) {
        self.points = points
        self.spans = spans
        self.updatedAt = updatedAt
    }
}
