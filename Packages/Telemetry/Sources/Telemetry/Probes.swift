import CaliperCore
import Foundation

public struct LatencyProbe: TelemetryProbe {
    public let name = "latency"
    private var startedAt: [UUID: Date] = [:]
    private var firstTokenAt: [UUID: Date] = [:]

    public init() {}

    public mutating func handle(_ event: InferenceLifecycleEvent) async -> [TelemetryPoint] {
        switch event {
        case .inferenceStarted(let request, let timestamp):
            startedAt[request.id] = timestamp
            return []
        case .tokenProduced(let token):
            guard firstTokenAt[token.requestID] == nil, let start = startedAt[token.requestID] else {
                return []
            }
            firstTokenAt[token.requestID] = token.timestamp
            return [
                TelemetryPoint(
                    name: "llm.inference.ttft",
                    value: token.timestamp.timeIntervalSince(start),
                    unit: "s",
                    timestamp: token.timestamp,
                    attributes: ["request.id": token.requestID.uuidString]
                )
            ]
        case .inferenceCompleted(let result, let timestamp):
            guard let start = startedAt.removeValue(forKey: result.requestID) else {
                return []
            }
            firstTokenAt.removeValue(forKey: result.requestID)
            return [
                TelemetryPoint(
                    name: "llm.inference.duration",
                    value: timestamp.timeIntervalSince(start),
                    unit: "s",
                    timestamp: timestamp,
                    attributes: ["request.id": result.requestID.uuidString]
                )
            ]
        case .inferenceFailed(let requestID, _, _):
            startedAt.removeValue(forKey: requestID)
            firstTokenAt.removeValue(forKey: requestID)
            return []
        case .modelLoadStarted, .modelLoaded:
            return []
        }
    }
}

public struct TokenThroughputProbe: TelemetryProbe {
    public let name = "token-throughput"
    private var firstTokenAt: [UUID: Date] = [:]
    private var tokenCounts: [UUID: Int] = [:]

    public init() {}

    public mutating func handle(_ event: InferenceLifecycleEvent) async -> [TelemetryPoint] {
        switch event {
        case .tokenProduced(let token):
            if firstTokenAt[token.requestID] == nil {
                firstTokenAt[token.requestID] = token.timestamp
            }
            tokenCounts[token.requestID, default: 0] += 1

            guard let start = firstTokenAt[token.requestID] else { return [] }
            let elapsed = max(token.timestamp.timeIntervalSince(start), 0.001)
            let rate = Double(tokenCounts[token.requestID, default: 0]) / elapsed

            return [
                TelemetryPoint(
                    name: "llm.tokens.per_second",
                    value: rate,
                    unit: "tokens/s",
                    timestamp: token.timestamp,
                    attributes: ["request.id": token.requestID.uuidString]
                )
            ]
        case .inferenceCompleted(let result, _):
            firstTokenAt.removeValue(forKey: result.requestID)
            tokenCounts.removeValue(forKey: result.requestID)
            return []
        case .inferenceFailed(let requestID, _, _):
            firstTokenAt.removeValue(forKey: requestID)
            tokenCounts.removeValue(forKey: requestID)
            return []
        case .modelLoadStarted, .modelLoaded, .inferenceStarted:
            return []
        }
    }
}

public struct ThermalProbe: TelemetryProbe {
    public let name = "thermal"

    public init() {}

    public mutating func handle(_ event: InferenceLifecycleEvent) async -> [TelemetryPoint] {
        switch event {
        case .inferenceStarted, .tokenProduced, .inferenceCompleted, .modelLoaded:
            let state = ProcessInfo.processInfo.thermalState
            return [
                TelemetryPoint(
                    name: "device.thermal.state",
                    value: Double(state.rawValue),
                    unit: "state",
                    attributes: ["thermal.state": state.label]
                )
            ]
        case .modelLoadStarted, .inferenceFailed:
            return []
        }
    }
}

public struct MemoryProbe: TelemetryProbe {
    public let name = "memory"

    public init() {}

    public mutating func handle(_ event: InferenceLifecycleEvent) async -> [TelemetryPoint] {
        switch event {
        case .modelLoaded, .inferenceStarted, .tokenProduced, .inferenceCompleted:
            return [
                TelemetryPoint(
                    name: "process.memory.resident",
                    value: Double(MemorySampler.residentMemoryBytes()),
                    unit: "By"
                )
            ]
        case .modelLoadStarted, .inferenceFailed:
            return []
        }
    }
}

public struct BatteryProbe: TelemetryProbe {
    public let name = "battery"

    public init() {}

    public mutating func handle(_ event: InferenceLifecycleEvent) async -> [TelemetryPoint] {
        switch event {
        case .inferenceStarted, .inferenceCompleted, .modelLoaded:
            let battery = BatterySampler.current()
            return [
                TelemetryPoint(
                    name: "device.battery.level",
                    value: battery.level,
                    unit: "1",
                    attributes: ["battery.state": battery.state]
                )
            ]
        case .modelLoadStarted, .tokenProduced, .inferenceFailed:
            return []
        }
    }
}

private extension ProcessInfo.ThermalState {
    var label: String {
        switch self {
        case .nominal:
            return "nominal"
        case .fair:
            return "fair"
        case .serious:
            return "serious"
        case .critical:
            return "critical"
        @unknown default:
            return "unknown"
        }
    }
}
