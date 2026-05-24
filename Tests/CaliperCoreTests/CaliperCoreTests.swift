import CaliperCore
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
}
