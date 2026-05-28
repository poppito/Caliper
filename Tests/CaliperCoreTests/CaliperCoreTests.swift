import CaliperCore
import Exporters
import RuntimeAdapters
import Telemetry
import Validators
import XCTest

final class CaliperCoreTests: XCTestCase {
    func testJSONValidatorReportsMissingKeys() {
        let validator = JSONSchemaLiteValidator(requiredTopLevelKeys: ["summary", "risk"])

        let result = validator.validate(#"{"summary":"ok"}"#)

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.missingRequiredKeys, ["risk"])
    }

    func testLatencyProbeEmitsDuration() async {
        var probe = LatencyProbe()
        let request = InferenceRequest(prompt: "hello")

        _ = await probe.handle(.inferenceStarted(request: request, timestamp: Date()))
        let points = await probe.handle(
            .inferenceCompleted(
                result: InferenceResult(requestID: request.id, output: "ok", tokenCount: 1),
                timestamp: Date().addingTimeInterval(1)
            )
        )

        XCTAssertEqual(points.first?.name, "llm.inference.duration")
    }

    func testLatencyProbeEmitsPrefillAndDecodeDurations() async {
        var probe = LatencyProbe()
        let request = InferenceRequest(prompt: "hello")
        let start = Date()

        _ = await probe.handle(.inferenceStarted(request: request, timestamp: start))
        let firstTokenPoints = await probe.handle(
            .tokenProduced(
                TokenEvent(
                    requestID: request.id,
                    index: 0,
                    text: "ok",
                    timestamp: start.addingTimeInterval(0.25)
                )
            )
        )
        let completedPoints = await probe.handle(
            .inferenceCompleted(
                result: InferenceResult(requestID: request.id, output: "ok", tokenCount: 1),
                timestamp: start.addingTimeInterval(1.0)
            )
        )

        XCTAssertTrue(firstTokenPoints.contains { $0.name == "llm.inference.prefill.duration" })
        XCTAssertTrue(completedPoints.contains { $0.name == "llm.inference.decode.duration" })
    }

    func testRunComparisonComputesMetricDelta() {
        let baseline = TelemetrySnapshot(points: [
            TelemetryPoint(name: "llm.tokens.per_second", value: 10, unit: "tokens/s"),
            TelemetryPoint(name: "llm.tokens.per_second", value: 20, unit: "tokens/s")
        ])
        let candidate = TelemetrySnapshot(points: [
            TelemetryPoint(name: "llm.tokens.per_second", value: 30, unit: "tokens/s")
        ])

        let comparison = TelemetryRunComparison(baseline: baseline, candidate: candidate)
        let delta = comparison.delta(named: "llm.tokens.per_second")

        XCTAssertEqual(delta?.baselineAverage, 15)
        XCTAssertEqual(delta?.candidateAverage, 30)
        XCTAssertEqual(delta?.percentChange, 100)
    }

    func testTelemetryCollectorCapturesDeviceMetadata() async {
        let collector = TelemetryCollector(captureDeviceMetadata: true)
        let snapshot = await collector.snapshot

        XCTAssertNotNil(snapshot.device)
        XCTAssertFalse(snapshot.device?.systemVersion.isEmpty ?? true)
    }

    func testMetricKitTelemetryPointUsesPayloadCount() {
        let point = MetricKitTelemetry.point(kind: "metric", payloadCount: 2)

        XCTAssertEqual(point.name, "apple.metrickit.payload.received")
        XCTAssertEqual(point.value, 2)
        XCTAssertEqual(point.attributes["metrickit.kind"], "metric")
    }

    func testRuntimeFactoryCanCreateExplicitAdapterBoundaries() {
        let mlxRuntime = RuntimeFactory.makeRuntime(
            modelURL: nil,
            modelIdentifier: "test-model",
            preferredRuntime: .mlx
        )
        let coreMLRuntime = RuntimeFactory.makeRuntime(
            modelURL: nil,
            modelIdentifier: "test-model",
            preferredRuntime: .coreML
        )
        let foundationRuntime = RuntimeFactory.makeRuntime(
            modelURL: nil,
            modelIdentifier: "test-model",
            preferredRuntime: .foundationModels
        )

        XCTAssertEqual(mlxRuntime.runtimeName, "MLX")
        XCTAssertEqual(coreMLRuntime.runtimeName, "Core ML")
        XCTAssertEqual(foundationRuntime.runtimeName, "Foundation Models")
    }

    func testShipReportMarksSlowRunAsNoShip() {
        let snapshot = TelemetrySnapshot(points: [
            TelemetryPoint(name: "llm.inference.ttft", value: 3.5, unit: "s"),
            TelemetryPoint(name: "llm.tokens.per_second", value: 4, unit: "tokens/s")
        ])

        let report = ShipReport(snapshot: snapshot)

        XCTAssertEqual(report.decision, .noShip)
        XCTAssertTrue(report.markdown.contains("Decision: no-ship"))
    }
}
