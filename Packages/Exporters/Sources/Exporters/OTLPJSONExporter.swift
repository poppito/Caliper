import CaliperCore
import Foundation

public struct OTLPJSONExporter: TraceExporter {
    public var outputURL: URL
    public var serviceName: String

    public init(outputURL: URL, serviceName: String = "caliper-ios") {
        self.outputURL = outputURL
        self.serviceName = serviceName
    }

    public func export(_ snapshot: TelemetrySnapshot) async throws {
        let payload = OTLPTracePayload.from(snapshot: snapshot, serviceName: serviceName)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(payload)
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: outputURL, options: .atomic)
        } catch {
            throw CaliperError.exportFailed(error.localizedDescription)
        }
    }
}

public struct OTLPTracePayload: Codable, Sendable {
    public var resourceSpans: [ResourceSpan]
    public var resourceMetrics: [ResourceMetric]

    public static func from(snapshot: TelemetrySnapshot, serviceName: String) -> OTLPTracePayload {
        OTLPTracePayload(
            resourceSpans: [
                ResourceSpan(
                    resource: Resource(attributes: [
                        Attribute(key: "service.name", value: serviceName),
                        Attribute(key: "telemetry.sdk.name", value: "caliper")
                    ]),
                    scopeSpans: [
                        ScopeSpan(
                            scope: Scope(name: "Caliper"),
                            spans: snapshot.spans.map(Span.init)
                        )
                    ]
                )
            ],
            resourceMetrics: [
                ResourceMetric(
                    resource: Resource(attributes: [
                        Attribute(key: "service.name", value: serviceName)
                    ]),
                    scopeMetrics: [
                        ScopeMetric(
                            scope: Scope(name: "Caliper"),
                            metrics: snapshot.points.map(Metric.init)
                        )
                    ]
                )
            ]
        )
    }

    public struct ResourceSpan: Codable, Sendable {
        public var resource: Resource
        public var scopeSpans: [ScopeSpan]
    }

    public struct ResourceMetric: Codable, Sendable {
        public var resource: Resource
        public var scopeMetrics: [ScopeMetric]
    }

    public struct Resource: Codable, Sendable {
        public var attributes: [Attribute]
    }

    public struct ScopeSpan: Codable, Sendable {
        public var scope: Scope
        public var spans: [Span]
    }

    public struct ScopeMetric: Codable, Sendable {
        public var scope: Scope
        public var metrics: [Metric]
    }

    public struct Scope: Codable, Sendable {
        public var name: String
    }

    public struct Attribute: Codable, Sendable {
        public var key: String
        public var value: String
    }

    public struct Span: Codable, Sendable {
        public var traceId: String
        public var spanId: String
        public var name: String
        public var startTimeUnixNano: UInt64
        public var endTimeUnixNano: UInt64?
        public var attributes: [Attribute]
        public var events: [String]

        public init(_ span: CaliperSpan) {
            self.traceId = span.id.uuidString.replacingOccurrences(of: "-", with: "")
            self.spanId = String(traceId.prefix(16))
            self.name = span.name
            self.startTimeUnixNano = span.start.nanosecondsSince1970
            self.endTimeUnixNano = span.end?.nanosecondsSince1970
            self.attributes = span.attributes.map { Attribute(key: $0.key, value: $0.value) }
            self.events = span.events
        }
    }

    public struct Metric: Codable, Sendable {
        public var name: String
        public var unit: String
        public var dataPoints: [NumberDataPoint]

        public init(_ point: TelemetryPoint) {
            self.name = point.name
            self.unit = point.unit
            self.dataPoints = [
                NumberDataPoint(
                    timeUnixNano: point.timestamp.nanosecondsSince1970,
                    asDouble: point.value,
                    attributes: point.attributes.map { Attribute(key: $0.key, value: $0.value) }
                )
            ]
        }
    }

    public struct NumberDataPoint: Codable, Sendable {
        public var timeUnixNano: UInt64
        public var asDouble: Double
        public var attributes: [Attribute]
    }
}

private extension Date {
    var nanosecondsSince1970: UInt64 {
        UInt64(timeIntervalSince1970 * 1_000_000_000)
    }
}
