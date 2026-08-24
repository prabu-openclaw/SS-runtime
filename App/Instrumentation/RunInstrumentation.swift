import Foundation
import UIKit

/// T900: collects frame-time percentiles from presentation updates.
public final class FrameTimeCollector {
    private var frameTimesMs: [Double] = []
    private var lastTimestamp: TimeInterval?
    private let lock = NSLock()

    public init() {}

    public func recordFrame(timestamp: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        if let last = lastTimestamp {
            let deltaMs = (timestamp - last) * 1000
            if deltaMs > 0, deltaMs < 1000 {
                frameTimesMs.append(deltaMs)
            }
        }
        lastTimestamp = timestamp
    }

    public struct Summary: Equatable, Sendable {
        public var sampleCount: Int
        public var p50Ms: Double
        public var p95Ms: Double
        public var p99Ms: Double
        public var worstMs: Double
        public var sustainedBelowFloorFps: Bool

        public func passesGateC() -> Bool {
            sampleCount > 0
                && p50Ms <= PerformanceThresholds.frameTimeP50Ms
                && p95Ms <= PerformanceThresholds.frameTimeP95Ms
                && p99Ms <= PerformanceThresholds.frameTimeP99Ms
                && worstMs <= PerformanceThresholds.frameTimeWorstMs
                && !sustainedBelowFloorFps
        }
    }

    public func summarize() -> Summary {
        lock.lock()
        let samples = frameTimesMs
        lock.unlock()

        guard !samples.isEmpty else {
            return Summary(
                sampleCount: 0,
                p50Ms: 0,
                p95Ms: 0,
                p99Ms: 0,
                worstMs: 0,
                sustainedBelowFloorFps: false
            )
        }

        let sorted = samples.sorted()
        let count = sorted.count
        func percentile(_ p: Double) -> Double {
            let index = min(count - 1, max(0, Int((p * Double(count - 1)).rounded(.down))))
            return sorted[index]
        }

        let floorMs = 1000.0 / Double(PerformanceThresholds.sustainedPresentationFloorFps)
        var sustainedBelow = false
        var streak = 0
        for sample in sorted {
            if sample > floorMs {
                streak += 1
                if streak >= 3 { sustainedBelow = true }
            } else {
                streak = 0
            }
        }

        return Summary(
            sampleCount: count,
            p50Ms: percentile(0.50),
            p95Ms: percentile(0.95),
            p99Ms: percentile(0.99),
            worstMs: sorted.last ?? 0,
            sustainedBelowFloorFps: sustainedBelow
        )
    }

    public func reset() {
        lock.lock()
        frameTimesMs.removeAll(keepingCapacity: true)
        lastTimestamp = nil
        lock.unlock()
    }
}

/// T900: samples memory pressure and thermal state alongside simulation telemetry.
public struct DeviceTelemetrySample: Equatable, Sendable {
    public var residentMemoryBytes: UInt64
    public var thermalState: String
    public var memoryWarningCount: Int

    public static func capture(memoryWarningCount: Int) -> DeviceTelemetrySample {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        let resident = result == KERN_SUCCESS ? info.resident_size : 0
        let thermalLabel: String = switch ProcessInfo.processInfo.thermalState {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        @unknown default: "unknown"
        }
        return DeviceTelemetrySample(
            residentMemoryBytes: resident,
            thermalState: thermalLabel,
            memoryWarningCount: memoryWarningCount
        )
    }
}

/// T900: aggregates frame, device, and simulation telemetry for release-candidate evidence (T907).
public final class RunInstrumentation {
    public let frameTimes = FrameTimeCollector()
    public private(set) var memoryWarningCount = 0
    public private(set) var peakSimulationTelemetry: RunTelemetrySnapshot?
    public private(set) var terminalTelemetry: RunTelemetrySnapshot?

    public init() {}

    public func noteMemoryWarning() {
        memoryWarningCount += 1
    }

    public func recordSimulation(_ state: WorldState) {
        let sample = RunTelemetrySnapshot(state)
        if peakSimulationTelemetry == nil || sample.entities.totalLive > peakSimulationTelemetry!.entities.totalLive {
            peakSimulationTelemetry = sample
        }
        if state.outcome != .playing {
            terminalTelemetry = sample
        }
    }

    public struct Evidence: Equatable, Sendable {
        public var schemaVersion: String
        public var frameTime: FrameTimeCollector.Summary
        public var device: DeviceTelemetrySample
        public var peakSimulation: RunTelemetrySnapshot?
        public var terminalSimulation: RunTelemetrySnapshot?
    }

    public func evidence() -> Evidence {
        Evidence(
            schemaVersion: "run-instrumentation-001",
            frameTime: frameTimes.summarize(),
            device: DeviceTelemetrySample.capture(memoryWarningCount: memoryWarningCount),
            peakSimulation: peakSimulationTelemetry,
            terminalSimulation: terminalTelemetry
        )
    }

    public func reset() {
        frameTimes.reset()
        memoryWarningCount = 0
        peakSimulationTelemetry = nil
        terminalTelemetry = nil
    }
}
