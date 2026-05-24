import CaliperCore
import Foundation

public struct StructuredValidationResult: Codable, Equatable, Sendable {
    public var isValid: Bool
    public var message: String
    public var keysPresent: [String]
    public var missingRequiredKeys: [String]

    public init(
        isValid: Bool,
        message: String,
        keysPresent: [String] = [],
        missingRequiredKeys: [String] = []
    ) {
        self.isValid = isValid
        self.message = message
        self.keysPresent = keysPresent
        self.missingRequiredKeys = missingRequiredKeys
    }
}

public protocol StructuredOutputValidator: Sendable {
    func validate(_ output: String) -> StructuredValidationResult
}

public struct JSONSchemaLiteValidator: StructuredOutputValidator {
    public var requiredTopLevelKeys: Set<String>

    public init(requiredTopLevelKeys: Set<String> = []) {
        self.requiredTopLevelKeys = requiredTopLevelKeys
    }

    public func validate(_ output: String) -> StructuredValidationResult {
        guard let data = output.data(using: .utf8) else {
            return StructuredValidationResult(isValid: false, message: "Output is not UTF-8.")
        }

        do {
            let object = try JSONSerialization.jsonObject(with: data)

            guard let dictionary = object as? [String: Any] else {
                return StructuredValidationResult(isValid: false, message: "Top-level JSON value is not an object.")
            }

            let keys = Set(dictionary.keys)
            let missing = requiredTopLevelKeys.subtracting(keys).sorted()

            return StructuredValidationResult(
                isValid: missing.isEmpty,
                message: missing.isEmpty ? "Valid structured output." : "Missing required keys.",
                keysPresent: dictionary.keys.sorted(),
                missingRequiredKeys: missing
            )
        } catch {
            return StructuredValidationResult(
                isValid: false,
                message: "JSON parse failed: \(error.localizedDescription)"
            )
        }
    }
}

public struct StructuredOutputProbe {
    public var validator: any StructuredOutputValidator

    public init(validator: any StructuredOutputValidator) {
        self.validator = validator
    }

    public func point(for result: InferenceResult) -> TelemetryPoint {
        let validation = validator.validate(result.output)
        return TelemetryPoint(
            name: "llm.output.structured.valid",
            value: validation.isValid ? 1 : 0,
            unit: "1",
            attributes: [
                "request.id": result.requestID.uuidString,
                "validation.message": validation.message,
                "validation.missing_keys": validation.missingRequiredKeys.joined(separator: ",")
            ]
        )
    }
}
