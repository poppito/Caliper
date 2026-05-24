# Caliper

Caliper is an iOS-native observability and telemetry framework for on-device AI inference workloads running on physical Apple hardware.

It is not a benchmark app. Caliper is for inference observability, runtime telemetry, operational profiling, and edge AI diagnostics.

Caliper answers:

> How does this model behave operationally on real iOS hardware under sustained inference workloads?

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

`Telemetry` contains the probe system and built-in probes for latency, TTFT, token throughput, memory, thermal state, battery state, and signposts.

`Exporters` writes local Caliper JSON and OTLP-shaped JSON payloads. It also imports the official OpenTelemetry Swift API/SDK so backend exporters can be added without changing core APIs.

`Dashboards` provides embedded SwiftUI and Swift Charts views for local telemetry visualization.

`Validators` validates structured output, starting with JSON object adherence and required top-level keys.

`Workloads` provides repeatable local inference workload helpers for smoke tests and structured-output diagnostics.

## Quick Start

Add the package to an iOS 16+ app:

```swift
.package(url: "https://github.com/your-org/caliper.git", from: "0.1.0")
```

Create a session:

```swift
import CaliperCore
import RuntimeAdapters
import Telemetry
import Workloads

let runtime = SimulatedLlamaRuntime()
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

## llama.cpp Integration

v1 starts with llama.cpp as the intended runtime. The package does not bundle llama.cpp or model binaries. Host apps should provide a concrete token provider or extend `LlamaCppRuntimeAdapter` with their own C/Swift bridge.

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
