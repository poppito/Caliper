# Caliper Architecture

Caliper is organized around one source of truth: inference lifecycle events.

```text
InferenceRuntime
    -> CaliperSession
    -> InferenceLifecycleEvent stream
    -> TelemetryCollector
    -> Probes
    -> Snapshots
    -> Dashboards and Exporters
```

## Design Principles

- Local-first.
- Runtime instrumentation before benchmark scoring.
- OpenTelemetry concepts without requiring infrastructure.
- Physical-device behavior over simulator performance.
- Small v1 surface area.

## Runtime Boundary

`InferenceRuntime` abstracts a local inference engine. The only required operations are model load and prompt execution with token streaming.

This keeps llama.cpp-specific details out of telemetry and dashboards.

## Probe System

Probes subscribe to lifecycle events and emit metric points.

Each probe is small, stateful, and independent:

- `LatencyProbe`
- `TokenThroughputProbe`
- `ThermalProbe`
- `MemoryProbe`
- `BatteryProbe`

## Export Model

Caliper has two local exporters:

- `JSONTraceExporter`: Caliper-native JSON envelope.
- `OTLPJSONExporter`: OTLP-shaped JSON for local inspection or collector ingestion.

## Dashboard Model

Dashboards render a `TelemetrySnapshot`. They do not own runtime execution, exports, or probes.
