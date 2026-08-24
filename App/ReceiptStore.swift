import Foundation
import SurveillanceCore

/// ER-006: persists terminal run receipts to Application Support.
enum ReceiptStore {
    private static let subdirectory = "RunReceipts"

    static func directoryURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base.appendingPathComponent(subdirectory, isDirectory: true)
    }

    static func archive() throws -> ReceiptArchive {
        ReceiptArchive(directory: try directoryURL())
    }

    @discardableResult
    static func persistTerminalReceipt(for state: WorldState) throws -> ReceiptArchiveEntry? {
        guard state.outcome != .playing else { return nil }
        let receipt = RunReceipt(state)
        return try archive().store(receipt)
    }
}
