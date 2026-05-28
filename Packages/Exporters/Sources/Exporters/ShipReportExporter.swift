import CaliperCore
import Foundation

public enum ShipDecision: String, Codable, Equatable, Sendable {
    case ship = "ship"
    case review = "review"
    case noShip = "no-ship"
}

public struct ShipReportThresholds: Codable, Equatable, Sendable {
    public var maximumTTFTSeconds: Double
    public var minimumTokensPerSecond: Double
    public var maximumResidentMemoryBytes: Double?
    public var allowsSeriousThermalState: Bool

    public init(
        maximumTTFTSeconds: Double = 2.0,
        minimumTokensPerSecond: Double = 8.0,
        maximumResidentMemoryBytes: Double? = nil,
        allowsSeriousThermalState: Bool = false
    ) {
        self.maximumTTFTSeconds = maximumTTFTSeconds
        self.minimumTokensPerSecond = minimumTokensPerSecond
        self.maximumResidentMemoryBytes = maximumResidentMemoryBytes
        self.allowsSeriousThermalState = allowsSeriousThermalState
    }
}

public struct ShipReportFinding: Codable, Equatable, Sendable, Identifiable {
    public var id: String { metricName + message }
    public var metricName: String
    public var decision: ShipDecision
    public var message: String

    public init(metricName: String, decision: ShipDecision, message: String) {
        self.metricName = metricName
        self.decision = decision
        self.message = message
    }
}

public struct ShipReport: Codable, Equatable, Sendable {
    public var title: String
    public var generatedAt: Date
    public var decision: ShipDecision
    public var run: TelemetryRunSummary
    public var thresholds: ShipReportThresholds
    public var findings: [ShipReportFinding]

    public init(
        snapshot: TelemetrySnapshot,
        title: String = "Caliper Ship Report",
        thresholds: ShipReportThresholds = ShipReportThresholds(),
        generatedAt: Date = Date()
    ) {
        let run = TelemetryRunSummary(snapshot: snapshot)
        let findings = Self.evaluate(run: run, thresholds: thresholds)

        self.title = title
        self.generatedAt = generatedAt
        self.decision = Self.rollup(findings)
        self.run = run
        self.thresholds = thresholds
        self.findings = findings
    }

    public var markdown: String {
        var lines: [String] = [
            "# \(title)",
            "",
            "Decision: \(decision.rawValue)",
            "Generated: \(generatedAt.ISO8601Format())",
            "Run: \(run.name)"
        ]

        if let model = run.model {
            lines.append("Model: \(model.identifier) (\(model.runtime))")
        }

        if let device = run.device {
            lines.append("Device: \(device.name) \(device.hardwareModel ?? "") \(device.systemVersion)")
        }

        lines.append("")
        lines.append("## Key Metrics")

        for name in Self.keyMetricNames {
            guard let metric = run.metric(name) else { continue }
            lines.append("- \(name): avg \(Self.format(metric.average)) \(metric.unit), latest \(Self.format(metric.latest)) \(metric.unit), n=\(metric.count)")
        }

        lines.append("")
        lines.append("## Findings")

        if findings.isEmpty {
            lines.append("- ship: All configured thresholds passed.")
        } else {
            for finding in findings {
                lines.append("- \(finding.decision.rawValue): \(finding.message)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static let keyMetricNames = [
        "llm.inference.ttft",
        "llm.inference.prefill.duration",
        "llm.inference.decode.duration",
        "llm.tokens.per_second",
        "process.memory.resident",
        "device.thermal.state",
        "llm.output.structured.valid"
    ]

    private static func evaluate(
        run: TelemetryRunSummary,
        thresholds: ShipReportThresholds
    ) -> [ShipReportFinding] {
        var findings: [ShipReportFinding] = []

        if let ttft = run.metric("llm.inference.ttft"), ttft.average > thresholds.maximumTTFTSeconds {
            findings.append(
                ShipReportFinding(
                    metricName: ttft.name,
                    decision: .noShip,
                    message: "Average TTFT \(format(ttft.average))s exceeds \(format(thresholds.maximumTTFTSeconds))s."
                )
            )
        }

        if let throughput = run.metric("llm.tokens.per_second"), throughput.average < thresholds.minimumTokensPerSecond {
            findings.append(
                ShipReportFinding(
                    metricName: throughput.name,
                    decision: .noShip,
                    message: "Average throughput \(format(throughput.average)) tokens/s is below \(format(thresholds.minimumTokensPerSecond)) tokens/s."
                )
            )
        }

        if let maximumResidentMemoryBytes = thresholds.maximumResidentMemoryBytes,
           let memory = run.metric("process.memory.resident"),
           memory.maximum > maximumResidentMemoryBytes {
            findings.append(
                ShipReportFinding(
                    metricName: memory.name,
                    decision: .review,
                    message: "Peak resident memory \(format(memory.maximum)) bytes exceeds \(format(maximumResidentMemoryBytes)) bytes."
                )
            )
        }

        if !thresholds.allowsSeriousThermalState,
           let thermal = run.metric("device.thermal.state"),
           thermal.maximum >= 2 {
            findings.append(
                ShipReportFinding(
                    metricName: thermal.name,
                    decision: .review,
                    message: "Thermal state reached serious or critical during the run."
                )
            )
        }

        if let structured = run.metric("llm.output.structured.valid"), structured.latest < 1 {
            findings.append(
                ShipReportFinding(
                    metricName: structured.name,
                    decision: .review,
                    message: "Structured output validation failed on the latest run."
                )
            )
        }

        return findings
    }

    private static func rollup(_ findings: [ShipReportFinding]) -> ShipDecision {
        if findings.contains(where: { $0.decision == .noShip }) {
            return .noShip
        }
        if findings.contains(where: { $0.decision == .review }) {
            return .review
        }
        return .ship
    }

    private static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }
}

public struct MarkdownShipReportExporter {
    public var outputURL: URL
    public var thresholds: ShipReportThresholds

    public init(outputURL: URL, thresholds: ShipReportThresholds = ShipReportThresholds()) {
        self.outputURL = outputURL
        self.thresholds = thresholds
    }

    public func export(_ snapshot: TelemetrySnapshot) async throws {
        let report = ShipReport(snapshot: snapshot, thresholds: thresholds)

        do {
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try report.markdown.data(using: .utf8)?.write(to: outputURL, options: .atomic)
        } catch {
            throw CaliperError.exportFailed(error.localizedDescription)
        }
    }
}
