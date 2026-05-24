import CaliperCore
import Foundation

public struct JSONTraceExporter: TraceExporter {
    public var outputURL: URL
    public var prettyPrinted: Bool

    public init(outputURL: URL, prettyPrinted: Bool = true) {
        self.outputURL = outputURL
        self.prettyPrinted = prettyPrinted
    }

    public func export(_ snapshot: TelemetrySnapshot) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }

        let envelope = ExportEnvelope(snapshot: snapshot)
        let data = try encoder.encode(envelope)

        do {
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
