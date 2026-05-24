import CaliperCore
import Foundation
import os

public final class SignpostRecorder: @unchecked Sendable {
    private let log = OSLog(subsystem: "dev.caliper", category: "inference")
    private var signposts: [UUID: OSSignpostID] = [:]

    public init() {}

    public func record(_ event: InferenceLifecycleEvent) {
        switch event {
        case .inferenceStarted(let request, _):
            let signpostID = OSSignpostID(log: log)
            signposts[request.id] = signpostID
            os_signpost(.begin, log: log, name: "Inference", signpostID: signpostID, "%{public}s", request.id.uuidString)
        case .tokenProduced(let token):
            guard let signpostID = signposts[token.requestID] else { return }
            os_signpost(.event, log: log, name: "Token", signpostID: signpostID, "%{public}d", token.index)
        case .inferenceCompleted(let result, _):
            guard let signpostID = signposts.removeValue(forKey: result.requestID) else { return }
            os_signpost(.end, log: log, name: "Inference", signpostID: signpostID, "%{public}d", result.tokenCount)
        case .inferenceFailed(let requestID, let message, _):
            guard let signpostID = signposts.removeValue(forKey: requestID) else { return }
            os_signpost(.end, log: log, name: "Inference", signpostID: signpostID, "%{public}s", message)
        case .modelLoadStarted, .modelLoaded:
            break
        }
    }
}
