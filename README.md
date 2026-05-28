# Caliper

Caliper is an iOS-native observability and telemetry framework for on-device AI inference workloads running on physical Apple hardware.

It is not a benchmark app. Caliper is for inference observability, runtime telemetry, operational profiling, and edge AI diagnostics.

Caliper answers:

> How does this model behave operationally on real iOS hardware under sustained inference workloads?

## Screenshots


<img src="Docs/Screenshots/caliper1.PNG" width=240>
<img src="Docs/Screenshots/caliper2.PNG" width=240>
<img src="Docs/Screenshots/caliper3.PNG" width=240>


## Scope

Caliper v1 is intentionally small and local-first:

- Swift Package Manager
- Swift concurrency
- SwiftUI and Swift Charts dashboards
- `os_signpost` instrumentation
- MetricKit-ready architecture
- OpenTelemetry-oriented traces and metrics
- Local JSON export
- OTLP-compatible JSON export
- llama.cpp runtime adapter boundary
- No backend, accounts, cloud dashboard, or authentication

## Repository Layout

```text
Caliper/
├── Apps/
│   └── SampleApp/
├── Packages/
│   ├── CaliperCore/
│   ├── RuntimeAdapters/
│   ├── Telemetry/
│   ├── Dashboards/
│   ├── Exporters/
│   ├── Validators/
│   └── Workloads/
├── Docs/
├── Examples/
└── README.md
```

## Modules

`CaliperCore` defines inference runtime protocols, lifecycle events, telemetry models, spans, and the `CaliperSession` orchestrator.

`RuntimeAdapters` contains the llama.cpp adapter boundary and a simulated llama runtime for samples and tests.
It also includes `NativeLlamaCppRuntime` and `RuntimeFactory`, which automatically use a bundled GGUF when `llama.xcframework` is present.

`Telemetry` contains the probe system and built-in probes for latency, TTFT, token throughput, memory, thermal state, battery state, and signposts.

`Exporters` writes local Caliper JSON and OTLP-shaped JSON payloads. It also imports the official OpenTelemetry Swift API/SDK so backend exporters can be added without changing core APIs.

`Dashboards` provides embedded SwiftUI and Swift Charts views for local telemetry visualization.

`Validators` validates structured output, starting with JSON object adherence and required top-level keys.

`Workloads` provides repeatable local inference workload helpers for smoke tests and structured-output diagnostics.

## Quick Start

Add the package to an iOS 16+ app:

```swift
.package(url: "https://github.com/poppito/caliper.git", from: "0.1.0")
```

Create a session:

```swift
import CaliperCore
import RuntimeAdapters
import Telemetry
import Workloads

    private let collector = TelemetryCollector()
    private let session: CaliperSession
    private let runtime: any InferenceRuntime
    private let modelURL: URL?
    private let modelConfiguration = ModelConfiguration(
        fileName: "tinyllama-1.1b-chat-v1.0.Q2_K.gguf",
        quantization: "Q2_K"
    )

    init() {
        self.modelURL = modelConfiguration.resolvedURL()
        let runtime = RuntimeFactory.makeRuntime(
            modelURL: modelURL,
            modelIdentifier: modelConfiguration.identifier,
            quantization: modelConfiguration.quantization
        )
        self.runtime = runtime
        self.session = CaliperSession(runtime: runtime)
        self.runtimeDiagnostics = Self.describeRuntime(runtime, modelURL: modelURL)

        Task {
            for await latest in await collector.snapshots {
                await MainActor.run {
                    self.snapshot = latest
                }
            }
        }

        Task {
            for await event in await session.events {
                await collector.ingest(event)
                await MainActor.run {
                    self.handle(event: event)
                }
            }
        }
    }

let session = CaliperSession(runtime: runtime)
let collector = TelemetryCollector()
let runner = WorkloadRunner(session: session, collector: collector)

await runner.startCollecting()
let result = try await runner.run(.smoke)
let snapshot = await collector.snapshot
```

Export locally:

```swift
import Exporters

let exporter = JSONTraceExporter(outputURL: documentsURL.appendingPathComponent("caliper.json"))
try await exporter.export(snapshot)
```

Render dashboards:

```swift
import Dashboards

CaliperDashboardView(snapshot: snapshot)
```

## Bundling llama.cpp and a GGUF model

Caliper is designed to stay local-first, so the llama.cpp binary and model are intentionally not shipped through the framework packages.
Bundle them in the app target you are testing.

### Add `llama.xcframework`

1. Clone [llama.cpp](https://github.com/ggml-org/llama.cpp) and run `././build-xcframework.sh`
2. Go to `llama.cpp/build-apple`
3. Drag `llama.xcframework` into your Xcode app project.
4. Add it to the app target's `Link Binary With Libraries` build phase.
5. If Xcode treats it as an embedded framework in your setup, add it to `Embed Frameworks` with `Code Sign On Copy`.
6. Ensure your app target can import `llama` through its bridging header if you are using the native runtime path.

### Bundle a local quantized model

1. Choose a GGUF file such as `tinyllama-1.1b-chat-v1.0.Q2_K.gguf` or `TinyLlama-1.1B-Chat-v1.0.Q4_0.gguf`.
2. Add the file to the app target's `Copy Bundle Resources` build phase.
3. Make sure the filename you bundle matches the sample app's model configuration.
4. If you want a different model name, update the sample app configuration in `Apps/SampleApp/SampleCaliperApp/SampleCaliperApp/SampleCaliperAppApp.swift`.

### Runtime behavior

v1 starts with llama.cpp as the intended runtime. The package does not bundle llama.cpp or model binaries. Host apps should provide a concrete token provider or extend `LlamaCppRuntimeAdapter` with their own C/Swift bridge.
When `llama.xcframework` is present and the bundled model can be resolved, the sample app uses `NativeLlamaCppRuntime`. Otherwise it falls back to `SimulatedLlamaRuntime`.

The adapter emits:

- model load lifecycle
- inference start/end spans
- token stream events
- request metadata
- model metadata including quantization

## OpenTelemetry

Caliper telemetry maps directly to OpenTelemetry concepts:

- `CaliperSpan` maps to inference spans.
- `TelemetryPoint` maps to metric datapoints.
- `OTLPJSONExporter` emits an OTLP-shaped local JSON document.
- `OpenTelemetryBootstrap` imports the official OpenTelemetry Swift API/SDK as the integration boundary.

This keeps v1 backend-free while making future OTLP HTTP/gRPC export straightforward.

## What Caliper Measures

- Time to first token
- Inference duration
- Token throughput over time
- Resident memory usage
- Thermal state transitions
- Battery level/state snapshots
- Structured output validity
- Sustained throughput degradation
- Inference failures

## Status

This is a serious early-stage OSS foundation. The current implementation is intentionally narrow so the project can grow around real iPhone/iPad inference traces instead of speculative backend architecture.
