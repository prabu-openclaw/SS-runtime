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
        guard data.count >= 26 else { return nil }
        let signature: [UInt8] = [137, 80, 78, 71, 13, 10, 26, 10]
        guard data.prefix(8).elementsEqual(signature) else { return nil }
        guard data[12] == 73, data[13] == 72, data[14] == 68, data[15] == 82 else { return nil }
        let width = (Int(data[16]) << 24) | (Int(data[17]) << 16) | (Int(data[18]) << 8) | Int(data[19])
        let height = (Int(data[20]) << 24) | (Int(data[21]) << 16) | (Int(data[22]) << 8) | Int(data[23])
        guard width >= 1, height >= 1 else { return nil }
        return (width, height, data[25])
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
                if runtimePath.hasSuffix(".png"), !isValidDeliveryPNGName(runtimePath) {
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
            let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let byteCount = (attrs[.size] as? NSNumber)?.intValue ?? 0
            if byteCount <= 0 {
                issues.append(.emptyFile(record.assetId))
                continue
            }
            if let recorded = record.sha256 {
                if let previous = hashes[recorded], previous != record.assetId {
                    issues.append(.duplicateHash(recorded))
                } else {
                    hashes[recorded] = record.assetId
                }
            }
            guard source.hasSuffix(".png") else { continue }
            let handle = try FileHandle(forReadingFrom: fileURL)
            let prefix = try handle.read(upToCount: 33) ?? Data()
            try handle.close()
            guard let header = PNGHeader.parse(prefix) else {
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

    /// `name_parts@<scale>x.png` with at least two lowercase ident parts.
    public static func isValidDeliveryPNGName(_ name: String) -> Bool {
        guard name.hasSuffix(".png") else { return false }
        let stem = name.dropLast(4)
        guard let at = stem.lastIndex(of: "@") else { return false }
        let base = stem[stem.startIndex..<at]
        let scale = stem[stem.index(after: at)...]
        guard scale.count >= 2, scale.last == "x" else { return false }
        let digits = scale.dropLast()
        guard let first = digits.first, first >= "1", first <= "9",
              digits.allSatisfy({ $0 >= "0" && $0 <= "9" })
        else { return false }
        let parts = base.split(separator: "_", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return false }
        // Same character class as the asset ID this name must mirror
        // (`^[a-z0-9][a-zA-Z0-9_]*$`). clip-metadata-001 states clips in
        // camelCase, so `actor_camera_criticalEnter_none_01` is a legal ID and
        // must be a legal delivery name.
        guard let first = base.first, first.isLowercase || first.isNumber else { return false }
        return parts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy { ch in
                (ch >= "a" && ch <= "z") || (ch >= "A" && ch <= "Z") || (ch >= "0" && ch <= "9")
            }
        }
    }
}
