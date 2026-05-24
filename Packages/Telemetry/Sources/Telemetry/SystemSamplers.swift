import Foundation

#if canImport(Darwin)
import Darwin
import MachO
#endif

#if canImport(UIKit)
import UIKit
#endif

public enum MemorySampler {
    public static func residentMemoryBytes() -> UInt64 {
        #if canImport(Darwin)
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }
        return UInt64(info.resident_size)
        #else
        return 0
        #endif
    }
}

public struct BatteryReading: Sendable, Equatable {
    public var level: Double
    public var state: String

    public init(level: Double, state: String) {
        self.level = level
        self.state = state
    }
}

public enum BatterySampler {
    public static func current() -> BatteryReading {
        #if canImport(UIKit)
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel < 0 ? -1 : Double(UIDevice.current.batteryLevel)
        return BatteryReading(level: level, state: UIDevice.current.batteryState.label)
        #else
        return BatteryReading(level: -1, state: "unavailable")
        #endif
    }
}

#if canImport(UIKit)
private extension UIDevice.BatteryState {
    var label: String {
        switch self {
        case .unknown:
            return "unknown"
        case .unplugged:
            return "unplugged"
        case .charging:
            return "charging"
        case .full:
            return "full"
        @unknown default:
            return "unknown"
        }
    }
}
#endif
