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

The sample uses `SimulatedLlamaRuntime` so dashboards update without bundling llama.cpp or a model file.
