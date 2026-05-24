import CaliperCore
import Exporters
import RuntimeAdapters
import Telemetry
import Workloads
import Foundation

func runExample() async throws {
    let runtime = SimulatedLlamaRuntime()
    let session = CaliperSession(runtime: runtime)
    let collector = TelemetryCollector()
    let runner = WorkloadRunner(session: session, collector: collector)

    await runner.startCollecting()
    _ = try await runner.run(.smoke)

    let snapshot = await collector.snapshot
    let exporter = JSONTraceExporter(outputURL: URL(fileURLWithPath: "/tmp/caliper-trace.json"))
    try await exporter.export(snapshot)
}
