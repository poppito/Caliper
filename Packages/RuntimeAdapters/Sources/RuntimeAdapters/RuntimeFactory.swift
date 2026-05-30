import CaliperCore
import Foundation

public enum RuntimeFactory {
    public static func makeRuntime(
        modelURL: URL?,
        modelIdentifier: String,
        quantization: String? = nil,
        preferredRuntime: AppleInferenceRuntimeKind = .automatic
    ) -> any InferenceRuntime {
        switch preferredRuntime {
        case .mlx:
            return MLXRuntimeAdapter(modelIdentifier: modelIdentifier)
        case .coreML:
            return CoreMLRuntimeAdapter(modelURL: modelURL)
        case .foundationModels:
            return FoundationModelsRuntimeAdapter()
        case .simulated:
            return SimulatedLlamaRuntime(
                modelIdentifier: modelIdentifier,
                quantization: quantization ?? "unknown"
            )
        case .llamaCpp, .automatic:
            break
        }

        #if canImport(llama)
        if let modelURL {
            return NativeLlamaCppRuntime(
                modelURL: modelURL,
                quantization: quantization
            )
        }
        #endif

        return SimulatedLlamaRuntime(
            modelIdentifier: modelIdentifier,
            quantization: quantization ?? "unknown"
        )
    }
}
