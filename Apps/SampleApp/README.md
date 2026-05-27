# Caliper Sample App

This folder contains the source for a minimal SwiftUI iOS sample app.

To run it:

1. Create a new iOS SwiftUI app in Xcode.
2. Add the root Caliper package as a local Swift package.
3. Add these package products to the app target:
   - `CaliperCore`
   - `CaliperRuntimeAdapters`
   - `CaliperTelemetry`
   - `CaliperDashboards`
   - `CaliperWorkloads`
4. Replace the generated app source with `Sources/SampleApp/SampleApp.swift`.
5. Run on a physical iPhone or iPad.

The sample UI lets you edit the prompt and max token count before running a test.

The sample uses `SimulatedLlamaRuntime` so dashboards update without bundling llama.cpp or a model file.

To use a real model:

1. Add `llama.xcframework` to the sample app target.
2. Add your `.gguf` file to `Copy Bundle Resources`.
3. Make the bundled filename match the model configuration in `SampleCaliperAppApp.swift`.

When both are present, the sample app switches to `NativeLlamaCppRuntime` automatically through `RuntimeFactory`.
