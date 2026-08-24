import Foundation

public enum AssetIntakeIssue: Equatable, Sendable {
    case missingEvidenceFile(String)
    case hashMismatch(String)
    case dimensionMismatch(String)
    case colorSpace(String)
    case emptyFile(String)
    case duplicateHash(String)
    case artSourcesInRuntimePath(String)
    case acceptedWithoutFile(String)
    case undeclaredEvidenceFile(String)
    case invalidDeliveryName(String)
}

public enum PNGHeader {
    public static func parse(_ data: Data) -> (width: Int, height: Int, colorType: UInt8)? {
        let bytes = [UInt8](data)
        guard bytes.count >= 24 else { return nil }
        let signature: [UInt8] = [137, 80, 78, 71, 13, 10, 26, 10]
        guard bytes.prefix(8).elementsEqual(signature) else { return nil }
        guard bytes[12] == 73, bytes[13] == 72, bytes[14] == 68, bytes[15] == 82 else { return nil }
        let width = (Int(bytes[16]) << 24) | (Int(bytes[17]) << 16) | (Int(bytes[18]) << 8) | Int(bytes[19])
        let height = (Int(bytes[20]) << 24) | (Int(bytes[21]) << 16) | (Int(bytes[22]) << 8) | Int(bytes[23])
        guard width >= 1, height >= 1, bytes.count > 24 else { return nil }
        return (width, height, bytes[25])
    }
}

public enum AssetIntake {
    public static func validate(catalog: AssetCatalog, evidenceRoot: URL) throws -> [AssetIntakeIssue] {
        var issues: [AssetIntakeIssue] = []
        var hashes: [String: String] = [:]
        var declaredSources = Set<String>()

        for entry in catalog.entries {
            let record = entry.record
            if let runtimePath = record.runtimePath, runtimePath.hasPrefix("ArtSources/") {
                issues.append(.artSourcesInRuntimePath(record.assetId))
            }
            if record.productionStatus == .accepted {
                guard let runtimePath = record.runtimePath, !runtimePath.isEmpty else {
                    issues.append(.acceptedWithoutFile(record.assetId))
                    continue
                }
                if runtimePath.hasSuffix(".png"),
                   runtimePath.wholeMatch(of: /^[a-z0-9]+(?:_[a-z0-9]+)+@[1-9][0-9]*x\.png$/) == nil
                {
                    issues.append(.invalidDeliveryName(record.assetId))
                }
            }
            guard let source = record.source, source.hasPrefix("ArtSources/") else { continue }
            declaredSources.insert(source)
            let fileURL = evidenceRoot.appendingPathComponent(source)
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                issues.append(.missingEvidenceFile(record.assetId))
                continue
            }
            let data = try Data(contentsOf: fileURL)
            if data.isEmpty {
                issues.append(.emptyFile(record.assetId))
                continue
            }
            let digest = SHA256.hex(Array(data))
            if let expected = record.sha256, expected != digest {
                issues.append(.hashMismatch(record.assetId))
            }
            if record.sha256 != nil {
                if let previous = hashes[digest], previous != record.assetId {
                    issues.append(.duplicateHash(digest))
                } else {
                    hashes[digest] = record.assetId
                }
            }
            if source.hasSuffix(".png") {
                guard let header = PNGHeader.parse(data) else {
                    issues.append(.emptyFile(record.assetId))
                    continue
                }
                if let dimensions = record.dimensions,
                   dimensions.width != header.width || dimensions.height != header.height
                {
                    issues.append(.dimensionMismatch(record.assetId))
                }
                if let colorSpace = record.colorSpace, colorSpace != "sRGB" {
                    issues.append(.colorSpace(record.assetId))
                }
                let hasAlpha = header.colorType == 4 || header.colorType == 6
                if hasAlpha && record.alpha == "opaque" {
                    issues.append(.colorSpace(record.assetId))
                }
            }
        }

        let evidence = evidenceRoot.appendingPathComponent("ArtSources/legacy-evidence")
        if let enumerator = FileManager.default.enumerator(
            at: evidence,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            let prefix = evidence.standardizedFileURL.path
            while let url = enumerator.nextObject() as? URL {
                let values = try url.resourceValues(forKeys: [.isRegularFileKey])
                guard values.isRegularFile == true else { continue }
                if url.lastPathComponent == "README.md" { continue }
                let path = url.standardizedFileURL.path
                guard path.hasPrefix(prefix) else { continue }
                let suffix = String(path.dropFirst(prefix.count + 1))
                let relative = "ArtSources/legacy-evidence/" + suffix
                if !declaredSources.contains(relative) {
                    issues.append(.undeclaredEvidenceFile(relative))
                }
            }
        }

        return issues
    }
}
