import CaliperCore
import Foundation

public struct MetricKitReportEnvelope: Codable, Equatable, Sendable {
    public var kind: String
    public var receivedAt: Date
    public var payloadJSON: String

    public init(kind: String, receivedAt: Date = Date(), payloadJSON: String) {
        self.kind = kind
        self.receivedAt = receivedAt
        self.payloadJSON = payloadJSON
    }
}

public enum MetricKitTelemetry {
    public static func point(kind: String, payloadCount: Int, timestamp: Date = Date()) -> TelemetryPoint {
        TelemetryPoint(
            name: "apple.metrickit.payload.received",
            value: Double(payloadCount),
            unit: "payload",
            timestamp: timestamp,
            attributes: ["metrickit.kind": kind]
        )
    }
}

#if canImport(MetricKit)
import MetricKit

@available(iOS 13.0, macOS 12.0, *)
public final class MetricKitTelemetryBridge: NSObject, MXMetricManagerSubscriber {
    private let collector: TelemetryCollector?
    private let continuation: AsyncStream<MetricKitReportEnvelope>.Continuation

    public let reports: AsyncStream<MetricKitReportEnvelope>

    public init(collector: TelemetryCollector? = nil) {
        self.collector = collector

        var continuation: AsyncStream<MetricKitReportEnvelope>.Continuation!
        self.reports = AsyncStream { streamContinuation in
            continuation = streamContinuation
        }
        self.continuation = continuation

        super.init()
    }

    public func start() {
        MXMetricManager.shared.add(self)
    }

    public func stop() {
        MXMetricManager.shared.remove(self)
    }

    public func didReceive(_ payloads: [MXMetricPayload]) {
        receive(kind: "metric", payloads: payloads)
    }

    public func didReceive(_ payloads: [MXDiagnosticPayload]) {
        receive(kind: "diagnostic", payloads: payloads)
    }

    private func receive(kind: String, payloads: [any NSObjectProtocol]) {
        Task {
            await collector?.record(MetricKitTelemetry.point(kind: kind, payloadCount: payloads.count))
        }

        for payload in payloads {
            let payloadJSON = Self.payloadJSONString(payload)
            continuation.yield(MetricKitReportEnvelope(kind: kind, payloadJSON: payloadJSON))
        }
    }

    private static func payloadJSONString(_ payload: any NSObjectProtocol) -> String {
        if let metricPayload = payload as? MXMetricPayload {
            let data = metricPayload.jsonRepresentation()
            if let string = String(data: data, encoding: .utf8) {
                return string
            }
        }

        if let diagnosticPayload = payload as? MXDiagnosticPayload {
            let data = diagnosticPayload.jsonRepresentation()
            if let string = String(data: data, encoding: .utf8) {
                return string
            }
        }

        return "{}"
    }

    deinit {
        stop()
        continuation.finish()
    }
}
#endif
