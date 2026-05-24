import CaliperCore
import Foundation

public protocol TraceExporter: Sendable {
    func export(_ snapshot: TelemetrySnapshot) async throws
}

public struct ExportEnvelope: Codable, Sendable {
    public var schemaVersion: String
    public var generatedAt: Date
    public var snapshot: TelemetrySnapshot

    public init(
        schemaVersion: String = "caliper.telemetry.v1",
        generatedAt: Date = Date(),
        snapshot: TelemetrySnapshot
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.snapshot = snapshot
    }
}
