import CaliperCore
import Foundation

public enum RuntimeFactory {
    public static func makeRuntime(
        modelURL: URL?,
        modelIdentifier: String,
        quantization: String? = nil
    ) -> any InferenceRuntime {
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
