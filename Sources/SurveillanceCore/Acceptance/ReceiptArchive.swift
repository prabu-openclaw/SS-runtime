import Foundation

/// ER-006: atomic receipt persistence with 50-receipt retention.
public enum ReceiptArchiveError: Equatable, Sendable, Error {
    case invalidReceipt
    case writeFailed
}

public struct ReceiptArchiveEntry: Equatable, Sendable {
    public var filename: String
    public var digestPrefix: String
    public var serialized: String

    public init(filename: String, digestPrefix: String, serialized: String) {
        self.filename = filename
        self.digestPrefix = digestPrefix
        self.serialized = serialized
    }
}

public struct ReceiptArchive {
    public static let retentionLimit = 50

    private let directory: URL
    private let fileManager: FileManager
    private let clock: @Sendable () -> Date

    public init(
        directory: URL,
        fileManager: FileManager = .default,
        clock: @escaping @Sendable () -> Date = Date.init
    ) {
        self.directory = directory
        self.fileManager = fileManager
        self.clock = clock
    }

    public func store(_ receipt: RunReceipt) throws -> ReceiptArchiveEntry {
        let canonical = receipt.canonical()
        let serialized = canonical.serialize()
        guard serialized.utf8.count > 0, receipt.finalDigest.count >= 12 else {
            throw ReceiptArchiveError.invalidReceipt
        }

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = Self.filename(for: receipt, at: clock())
        let destination = directory.appendingPathComponent(filename)
        let temporary = directory.appendingPathComponent(".\(filename).tmp")

        guard let data = serialized.data(using: .utf8) else {
            throw ReceiptArchiveError.writeFailed
        }

        do {
            try data.write(to: temporary, options: .atomic)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: temporary, to: destination)
            try enforceRetentionLimit()
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw ReceiptArchiveError.writeFailed
        }

        return ReceiptArchiveEntry(
            filename: filename,
            digestPrefix: String(receipt.finalDigest.prefix(12)),
            serialized: serialized
        )
    }

    public func listEntries() throws -> [ReceiptArchiveEntry] {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "json" }
        .sorted { lhs, rhs in
            let leftDate = (try? lhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let rightDate = (try? rhs.resourceValues(forKeys: [.creationDateKey]).creationDate ?? .distantPast) ?? .distantPast
            if leftDate != rightDate { return leftDate < rightDate }
            return lhs.lastPathComponent < rhs.lastPathComponent
        }

        return try urls.map { url in
            let data = try Data(contentsOf: url)
            guard let serialized = String(data: data, encoding: .utf8) else {
                throw ReceiptArchiveError.invalidReceipt
            }
            let digestPrefix = Self.digestPrefix(fromFilename: url.lastPathComponent)
            return ReceiptArchiveEntry(
                filename: url.lastPathComponent,
                digestPrefix: digestPrefix,
                serialized: serialized
            )
        }
    }

    private func enforceRetentionLimit() throws {
        let entries = try listEntries()
        guard entries.count > Self.retentionLimit else { return }
        let overflow = entries.count - Self.retentionLimit
        for entry in entries.prefix(overflow) {
            let url = directory.appendingPathComponent(entry.filename)
            try fileManager.removeItem(at: url)
        }
    }

    public static func filename(for receipt: RunReceipt, at date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        let stamp = formatter.string(from: date)
        let prefix = String(receipt.finalDigest.prefix(12))
        return "run-\(stamp)-\(prefix).json"
    }

    public static func digestPrefix(fromFilename filename: String) -> String {
        let base = (filename as NSString).deletingPathExtension
        guard let suffix = base.split(separator: "-").last else { return "" }
        return String(suffix)
    }
}
