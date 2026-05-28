import Foundation

public struct MetricSummary: Codable, Equatable, Sendable {
    public var name: String
    public var unit: String
    public var count: Int
    public var minimum: Double
    public var maximum: Double
    public var average: Double
    public var latest: Double

    public init(name: String, unit: String, points: [TelemetryPoint]) {
        let values = points.map(\.value)
        self.name = name
        self.unit = points.first?.unit ?? ""
        self.count = values.count
        self.minimum = values.min() ?? 0
        self.maximum = values.max() ?? 0
        self.average = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        self.latest = points.sorted { $0.timestamp < $1.timestamp }.last?.value ?? 0
    }
}

public struct TelemetryRunSummary: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var model: ModelMetadata?
    public var device: DeviceMetadata?
    public var startedAt: Date?
    public var metrics: [String: MetricSummary]

    public init(snapshot: TelemetrySnapshot, fallbackName: String = "Telemetry Run") {
        self.id = snapshot.run?.id ?? UUID()
        self.name = snapshot.run?.name ?? fallbackName
        self.model = snapshot.run?.model
        self.device = snapshot.device
        self.startedAt = snapshot.run?.startedAt

        let grouped = Dictionary(grouping: snapshot.points, by: \.name)
        self.metrics = grouped.mapValues { points in
            MetricSummary(name: points.first?.name ?? "", unit: points.first?.unit ?? "", points: points)
        }
    }

    public func metric(_ name: String) -> MetricSummary? {
        metrics[name]
    }
}

public struct MetricDelta: Codable, Equatable, Sendable, Identifiable {
    public var id: String { name }
    public var name: String
    public var unit: String
    public var baselineAverage: Double
    public var candidateAverage: Double
    public var absoluteChange: Double
    public var percentChange: Double?

    public init(name: String, baseline: MetricSummary, candidate: MetricSummary) {
        self.name = name
        self.unit = candidate.unit.isEmpty ? baseline.unit : candidate.unit
        self.baselineAverage = baseline.average
        self.candidateAverage = candidate.average
        self.absoluteChange = candidate.average - baseline.average
        self.percentChange = baseline.average == 0 ? nil : (absoluteChange / baseline.average) * 100
    }
}

public struct TelemetryRunComparison: Codable, Equatable, Sendable {
    public var baseline: TelemetryRunSummary
    public var candidate: TelemetryRunSummary
    public var deltas: [MetricDelta]

    public init(baseline: TelemetrySnapshot, candidate: TelemetrySnapshot) {
        self.init(
            baseline: TelemetryRunSummary(snapshot: baseline, fallbackName: "Baseline"),
            candidate: TelemetryRunSummary(snapshot: candidate, fallbackName: "Candidate")
        )
    }

    public init(baseline: TelemetryRunSummary, candidate: TelemetryRunSummary) {
        self.baseline = baseline
        self.candidate = candidate

        let commonMetricNames = Set(baseline.metrics.keys).intersection(candidate.metrics.keys)
        self.deltas = commonMetricNames.sorted().compactMap { name in
            guard let baselineMetric = baseline.metrics[name], let candidateMetric = candidate.metrics[name] else {
                return nil
            }
            return MetricDelta(name: name, baseline: baselineMetric, candidate: candidateMetric)
        }
    }

    public func delta(named name: String) -> MetricDelta? {
        deltas.first { $0.name == name }
    }
}
