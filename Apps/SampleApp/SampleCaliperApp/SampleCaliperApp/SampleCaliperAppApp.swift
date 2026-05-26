//
//  SampleCaliperAppApp.swift
//  SampleCaliperApp
//
//  Created by Harsh Overseer on 25/5/2026.
//

import SwiftUI
import Combine
import CaliperCore
import Dashboards
import RuntimeAdapters
import Telemetry

@main
struct SampleCaliperAppApp: App {
    var body: some Scene {
        WindowGroup {
            SampleContentView()
        }
    }
}

struct SampleContentView: View {
    @StateObject private var viewModel = SampleViewModel()
    @State private var prompt = ""
    @State private var maxTokens = 96
    @FocusState private var promptIsFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Test Prompt")
                            .font(.headline)

                        ZStack(alignment: .topLeading) {
                            if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Enter a prompt to run against the model")
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 18)
                            }

                            TextEditor(text: $prompt)
                                .focused($promptIsFocused)
                                .frame(minHeight: 120)
                                .padding(10)
                                .scrollContentBackground(.hidden)
                                .background(Color(.secondarySystemBackground))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Max Tokens")
                                    .font(.subheadline.weight(.semibold))
                                Stepper(value: $maxTokens, in: 1...512, step: 1) {
                                    Text("\(maxTokens)")
                                        .monospacedDigit()
                                }
                            }

                            Spacer(minLength: 0)

                            Button("Run Test") {
                                promptIsFocused = false
                                Task {
                                    await viewModel.run(prompt: prompt, maxTokens: maxTokens)
                                }
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Export JSON") {
                                Task { await viewModel.exportJSON() }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Live Result")
                                .font(.headline)

                            Spacer()

                            Text(viewModel.statusText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }

                        ScrollView {
                            Text(viewModel.liveOutput.isEmpty ? "Waiting for output..." : viewModel.liveOutput)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .foregroundStyle(viewModel.liveOutput.isEmpty ? .secondary : .primary)
                                .padding(12)
                        }
                        .frame(minHeight: 140)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Runtime Diagnostics")
                            .font(.headline)

                        Text(viewModel.runtimeDiagnostics)
                            .font(.footnote.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    CaliperDashboardView(snapshot: viewModel.snapshot)
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Caliper Sample")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        promptIsFocused = false
                    }
                }
            }
        }
        .task {
            await viewModel.prepare()
        }
    }
}

@MainActor
final class SampleViewModel: ObservableObject {
    private struct ModelConfiguration {
        let fileName: String
        let quantization: String

        var identifier: String {
            fileName
        }

        func resolvedURL(bundle: Bundle = .main) -> URL? {
            let baseName = (fileName as NSString).deletingPathExtension
            return bundle.url(forResource: baseName, withExtension: "gguf")
        }
    }

    @Published var snapshot = TelemetrySnapshot()
    @Published var liveOutput = ""
    @Published var statusText = "Idle"
    @Published var runtimeDiagnostics = "Resolving runtime..."

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

    func prepare() async {
        statusText = "Ready"
    }

    private static func describeRuntime(_ runtime: any InferenceRuntime, modelURL: URL?) -> String {
        if let native = runtime as? NativeLlamaCppRuntime {
            return """
            Runtime: \(native.runtimeName)
            Model path: \(native.modelPath)
            Bundle lookup: \(modelURL?.path ?? "not found")
            """
        }

        if let simulated = runtime as? SimulatedLlamaRuntime {
            return """
            Runtime: \(simulated.runtimeName)
            Fallback: simulated runtime in use
            Bundle lookup: \(modelURL?.path ?? "not found")
            """
        }

        return """
        Runtime: \(type(of: runtime))
        Bundle lookup: \(modelURL?.path ?? "not found")
        """
    }

    private func handle(event: InferenceLifecycleEvent) {
        switch event {
        case .modelLoadStarted:
            statusText = "Loading model..."
            liveOutput = ""
        case .modelLoaded(let metadata, _):
            statusText = "Loaded \(metadata.identifier)"
        case .inferenceStarted(let request, _):
            statusText = "Running \(request.maxTokens) tokens..."
            liveOutput = ""
        case .tokenProduced(let token):
            liveOutput += token.text
            statusText = "Streaming token \(token.index + 1)"
        case .inferenceCompleted(let result, _):
            liveOutput = result.output
            statusText = "Completed \(result.tokenCount) tokens"
        case .inferenceFailed(_, let message, _):
            statusText = "Failed: \(message)"
        }
    }

    func run(prompt: String, maxTokens: Int) async {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }

        liveOutput = ""
        statusText = "Queued"

        let request = InferenceRequest(
            prompt: trimmedPrompt,
            maxTokens: maxTokens,
            metadata: ["workload.name": "Custom Prompt"]
        )

        do {
            _ = try await session.run(request)
        } catch {
            statusText = "Failed: \(error.localizedDescription)"
        }
    }

    func exportJSON() async {
        // The package README shows exporter usage. The sample app keeps this
        // action as an integration point for host apps to choose their path.
    }
}
