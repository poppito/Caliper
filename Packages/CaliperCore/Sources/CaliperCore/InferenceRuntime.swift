import Foundation

public protocol InferenceRuntime: Sendable {
    var runtimeName: String { get }
    var modelMetadata: ModelMetadata? { get async }

func loadModel() async throws -> ModelMetadata
    func run(_ request: InferenceRequest) async throws -> AsyncThrowingStream<TokenEvent, Error>
}

public enum CaliperError: Error, LocalizedError, Sendable {
    case modelNotLoaded
    case runtimeUnavailable(String)
    case invalidOutput(String)
    case exportFailed(String)

    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "The inference runtime has not loaded a model."
        case .runtimeUnavailable(let reason):
            return "The inference runtime is unavailable: \(reason)"
        case .invalidOutput(let reason):
            return "The inference output is invalid: \(reason)"
        case .exportFailed(let reason):
            return "Telemetry export failed: \(reason)"
        }
    }
}
