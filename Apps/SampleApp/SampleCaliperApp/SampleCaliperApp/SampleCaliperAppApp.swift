//
//  SampleCaliperAppApp.swift
//  SampleCaliperApp
//
//  Created by Harsh Overseer on 25/5/2026.
//

import SwiftUI
import CaliperCore
import Dashboards
import RuntimeAdapters
import SwiftUI
import Telemetry
import Workloads

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

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack {
                    Button("Run Smoke Workload") {
                        Task { await viewModel.runSmoke() }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Export JSON") {
                        Task { await viewModel.exportJSON() }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)

                CaliperDashboardView(snapshot: viewModel.snapshot)
            }
            .navigationTitle("Caliper Sample")
        }
        .task {
            await viewModel.prepare()
        }
    }
}

@MainActor
final class SampleViewModel: ObservableObject {
    @Published var snapshot = TelemetrySnapshot()

    private let collector = TelemetryCollector()
    private let runner: WorkloadRunner

    init() {
        let runtime = SimulatedLlamaRuntime()
        let session = CaliperSession(runtime: runtime)
        self.runner = WorkloadRunner(session: session, collector: collector)
        Task {
            for await snapshot in await collector.snapshots {
                await MainActor.run {
                    self.snapshot = snapshot
                }
            }
        }
    }

    func prepare() async {
        await runner.startCollecting()
    }

    func runSmoke() async {
        try? await runner.run(.smoke)
    }

    func exportJSON() async {
        // The package README shows exporter usage. The sample app keeps this
        // action as an integration point for host apps to choose their path.
    }
}
