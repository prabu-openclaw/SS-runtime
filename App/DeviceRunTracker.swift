import Foundation
import SurveillanceCore

/// T905/T907: tracks consecutive successful complete runs on the performance floor.
final class DeviceRunTracker {
    private(set) var consecutiveCompleteRuns = 0

    func noteTerminalOutcome(_ outcome: RunOutcome) {
        if outcome == .success {
            consecutiveCompleteRuns += 1
        } else {
            consecutiveCompleteRuns = 0
        }
    }

    func reset() {
        consecutiveCompleteRuns = 0
    }
}
