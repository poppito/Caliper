import CaliperCore
import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public struct OpenTelemetryBootstrap: Sendable {
    public var serviceName: String
    public var serviceVersion: String

    public init(serviceName: String = "caliper-ios", serviceVersion: String = "0.1.0") {
        self.serviceName = serviceName
        self.serviceVersion = serviceVersion
    }

    public func install() {
        // v1 keeps SDK setup intentionally small. Exporters remain local-first,
        // while this module pins and imports the official OpenTelemetry Swift API/SDK
        // so hosted exporters can be added without changing CaliperCore.
    }
}
