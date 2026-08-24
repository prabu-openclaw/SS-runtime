import Foundation
import SurveillanceCore

/// T907: persists release-candidate and device-run evidence bundles.
enum ReleaseEvidenceStore {
    private static let subdirectory = "ReleaseEvidence"

    static func directoryURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base.appendingPathComponent(subdirectory, isDirectory: true)
    }

    static func exportDeviceRunEvidence(_ evidence: DeviceRunEvidence) throws -> URL {
        let directory = try directoryURL()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = "device-run-\(evidence.deviceClass.replacingOccurrences(of: " ", with: "-").lowercased())-\(evidence.consecutiveCompleteRuns).json"
        let url = directory.appendingPathComponent(filename)
        let payload = evidence.canonical().serialize()
        try payload.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func exportReleaseCandidateEvidence(
        playtestEvidence: [PlaytestEvidence] = [],
        deviceEvidence: [DeviceRunEvidence] = [],
        d021DeviceProfiling: D021Ceilings? = nil
    ) throws -> URL {
        let directory = try directoryURL()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let evidence = try ReleaseCandidateEvidenceCollector.collect(
            options: ReleaseCandidateEvidenceCollector.Options(
                playtestEvidence: playtestEvidence,
                deviceEvidence: deviceEvidence,
                d021DeviceProfiling: d021DeviceProfiling
            )
        )
        let filename = "release-candidate-\(evidence.peakDensityDigest.prefix(12)).json"
        let url = directory.appendingPathComponent(filename)
        try evidence.canonical().serialize().write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func playtestDirectoryURL() throws -> URL {
        let directory = try directoryURL().appendingPathComponent("PlaytestSessions", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func exportReleaseCandidateWithBundledPlaytests(
        deviceEvidence: [DeviceRunEvidence] = [],
        d021DeviceProfiling: D021Ceilings? = nil
    ) throws -> URL {
        let playtests = try PlaytestEvidenceLoader.loadAll(from: playtestDirectoryURL())
        return try exportReleaseCandidateEvidence(
            playtestEvidence: playtests,
            deviceEvidence: deviceEvidence,
            d021DeviceProfiling: d021DeviceProfiling
        )
    }
}

extension RunInstrumentation.Evidence {
    func makeDeviceRunEvidence(
        deviceClass: String,
        consecutiveCompleteRuns: Int,
        atlasMemoryBytes: UInt64
    ) -> DeviceRunEvidence {
        DeviceRunEvidence.performanceFloor(
            deviceClass: deviceClass,
            consecutiveCompleteRuns: consecutiveCompleteRuns,
            frameTimePassesGateC: frameTime.passesGateC(),
            memoryWarnings: device.memoryWarningCount,
            thermalState: device.thermalState,
            residentMemoryBytes: device.residentMemoryBytes,
            atlasMemoryBytes: atlasMemoryBytes
        )
    }
}
