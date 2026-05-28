#if canImport(SwiftUI) && canImport(Charts)
import CaliperCore
import Charts
import SwiftUI

public struct CaliperDashboardView: View {
    public var snapshot: TelemetrySnapshot

    public init(snapshot: TelemetrySnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                DashboardHeader(snapshot: snapshot)
                MetricPanel(title: "Inference Latency", points: points(named: "llm.inference.duration"))
                MetricPanel(title: "Prefill Duration", points: points(named: "llm.inference.prefill.duration"))
                MetricPanel(title: "Decode Duration", points: points(named: "llm.inference.decode.duration"))
                MetricPanel(title: "Time To First Token", points: points(named: "llm.inference.ttft"))
                MetricPanel(title: "Token Throughput", points: points(named: "llm.tokens.per_second"))
                MetricPanel(title: "Memory Usage", points: points(named: "process.memory.resident"))
                MetricPanel(title: "Thermal State", points: points(named: "device.thermal.state"))
                MetricPanel(title: "Battery Impact", points: points(named: "device.battery.level"))
                MetricPanel(title: "Structured Output Validity", points: points(named: "llm.output.structured.valid"))
                DegradationPanel(points: points(named: "llm.tokens.per_second"))
            }
            .padding()
        }
        .navigationTitle("Caliper")
    }

    private func points(named name: String) -> [TelemetryPoint] {
        snapshot.points
            .filter { $0.name == name }
            .sorted { $0.timestamp < $1.timestamp }
    }
}

public struct RunComparisonView: View {
    public var comparison: TelemetryRunComparison

    public init(comparison: TelemetryRunComparison) {
        self.comparison = comparison
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Run Comparison")
                    .font(.headline)
                Text("\(comparison.baseline.name) vs \(comparison.candidate.name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(comparison.deltas) { delta in
                HStack(alignment: .firstTextBaseline) {
                    Text(delta.name)
                        .font(.subheadline)
                        .lineLimit(2)
                    Spacer(minLength: 12)
                    Text(formatted(delta))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(delta.absoluteChange <= 0 ? .green : .orange)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(12)
        .background(Color.caliperPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatted(_ delta: MetricDelta) -> String {
        let change = delta.absoluteChange.formatted(.number.precision(.fractionLength(2)))
        guard let percent = delta.percentChange else {
            return "\(change) \(delta.unit)"
        }
        return "\(change) \(delta.unit) (\(percent.formatted(.number.precision(.fractionLength(1))))%)"
    }
}

private struct DashboardHeader: View {
    var snapshot: TelemetrySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Local Inference Telemetry")
                .font(.title2.bold())
            Text("\(snapshot.points.count) metrics · \(snapshot.spans.count) spans")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let device = snapshot.device {
                Text("\(device.name) · \(device.hardwareModel ?? device.systemName) · \(device.systemVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MetricPanel: View {
    var title: String
    var points: [TelemetryPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if let latest = points.last {
                    Text(formatted(latest))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Chart(points) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value(point.unit, point.value)
                )
                PointMark(
                    x: .value("Time", point.timestamp),
                    y: .value(point.unit, point.value)
                )
            }
            .frame(height: 160)
            .chartXAxis(.hidden)
        }
        .padding(12)
        .background(Color.caliperPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatted(_ point: TelemetryPoint) -> String {
        "\(point.value.formatted(.number.precision(.fractionLength(2)))) \(point.unit)"
    }
}

private struct DegradationPanel: View {
    var points: [TelemetryPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sustained Degradation")
                .font(.headline)

            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.caliperPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var summary: String {
        guard let first = points.first?.value, let last = points.last?.value, first > 0 else {
            return "Collect throughput points to calculate degradation."
        }

        let delta = ((last - first) / first) * 100
        return "Throughput changed \(delta.formatted(.number.precision(.fractionLength(1))))% over the captured run."
    }
}

private extension Color {
    static var caliperPanelBackground: Color {
        #if os(iOS)
        return Color(.secondarySystemBackground)
        #else
        return Color.gray.opacity(0.12)
        #endif
    }
}
#endif
