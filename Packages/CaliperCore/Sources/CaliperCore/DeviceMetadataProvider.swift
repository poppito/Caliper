import Foundation

#if canImport(Darwin)
import Darwin
#endif

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public extension DeviceMetadata {
    static func current() -> DeviceMetadata {
        DeviceMetadata(
            name: currentDeviceName(),
            systemName: currentSystemName(),
            systemVersion: currentSystemVersion(),
            hardwareModel: hardwareModelIdentifier(),
            thermalState: ProcessInfo.processInfo.thermalState.caliperLabel
        )
    }

    private static func currentDeviceName() -> String {
        #if canImport(UIKit)
        UIDevice.current.name
        #elseif canImport(AppKit)
        Host.current().localizedName ?? "Mac"
        #else
        "Unknown Device"
        #endif
    }

    private static func currentSystemName() -> String {
        #if canImport(UIKit)
        UIDevice.current.systemName
        #else
        "macOS"
        #endif
    }

    private static func currentSystemVersion() -> String {
        #if canImport(UIKit)
        UIDevice.current.systemVersion
        #else
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        #endif
    }

    private static func hardwareModelIdentifier() -> String? {
        #if canImport(Darwin)
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        guard size > 0 else { return nil }

        var machine = [CChar](repeating: 0, count: size)
        let result = sysctlbyname("hw.machine", &machine, &size, nil, 0)
        guard result == 0 else { return nil }

        return String(cString: machine)
        #else
        return nil
        #endif
    }
}

private extension ProcessInfo.ThermalState {
    var caliperLabel: String {
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
