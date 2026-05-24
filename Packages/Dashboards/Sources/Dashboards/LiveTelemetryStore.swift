import CaliperCore
import Combine
import Foundation

public final class LiveTelemetryStore: ObservableObject {
    @Published public var snapshot = TelemetrySnapshot()

    public init() {}

    public func update(_ snapshot: TelemetrySnapshot) {
        self.snapshot = snapshot
    }
}
