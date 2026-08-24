import Foundation

public struct VisualRange: Equatable, Sendable {
    public var min: Int
    public var max: Int
}

public struct VisualSalienceRank: Equatable, Sendable {
    public var rank: Int
    public var surface: String
    public var distinction: String
}

public struct VisualPaletteRole: Equatable, Sendable {
    public var role: String
    public var family: String
    public var nonColorCarrier: String
}

public struct VisualLanguage: Equatable, Sendable {
    public var schemaVersion: String
    public var visualVersion: String
    public var authoringGridUnits: Int
    public var actorFootprintUnits: VisualRange
    public var filtering: String
    public var salience: [VisualSalienceRank]
    public var palette: [VisualPaletteRole]
    public var spriteBoxes: [String: AssetDimensions]
    public var environmentModuleMultiple: Int
    public var atlases: [String]
    public var deliveryNamePattern: String
    public var colorIsNotSoleCarrier: Bool
    public var collisionNeverFromSpriteBounds: Bool
    public var groundContactMustBeStable: Bool

    public static func bundled() throws -> VisualLanguage {
        try VisualLanguageLoader.decode(SpecBundle.contract("visual-language-001"))
    }
}

public enum VisualLanguageError: Equatable, Sendable, Error {
    case invalidJSON
    case schemaVersion
    case salience
    case palette
    case boxes
}

enum VisualLanguageLoader {
    static func decode(_ data: Data) throws -> VisualLanguage {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw VisualLanguageError.invalidJSON
        }
        guard root["schemaVersion"] as? String == "visual-language-001" else {
            throw VisualLanguageError.schemaVersion
        }
        guard root["visualVersion"] as? String == "visual-civic-seam-001" else {
            throw VisualLanguageError.schemaVersion
        }
        guard let grid = intValue(root["authoringGridUnits"]), grid == 64 else {
            throw VisualLanguageError.boxes
        }
        guard let footprint = root["actorFootprintUnits"] as? [String: Any],
              let fpMin = intValue(footprint["min"]),
              let fpMax = intValue(footprint["max"]),
              fpMin == 28, fpMax == 36
        else {
            throw VisualLanguageError.boxes
        }
        guard let rawSalience = root["salience"] as? [[String: Any]], rawSalience.count == 9 else {
            throw VisualLanguageError.salience
        }
        var salience: [VisualSalienceRank] = []
        for (index, row) in rawSalience.enumerated() {
            guard let rank = intValue(row["rank"]), rank == index + 1,
                  let surface = row["surface"] as? String, !surface.isEmpty,
                  let distinction = row["distinction"] as? String, !distinction.isEmpty
            else {
                throw VisualLanguageError.salience
            }
            salience.append(VisualSalienceRank(rank: rank, surface: surface, distinction: distinction))
        }
        guard let rawPalette = root["palette"] as? [[String: Any]], rawPalette.count >= 11 else {
            throw VisualLanguageError.palette
        }
        let palette: [VisualPaletteRole] = try rawPalette.map { row in
            guard let role = row["role"] as? String, !role.isEmpty,
                  let family = row["family"] as? String, !family.isEmpty,
                  let carrier = row["nonColorCarrier"] as? String, !carrier.isEmpty
            else {
                throw VisualLanguageError.palette
            }
            return VisualPaletteRole(role: role, family: family, nonColorCarrier: carrier)
        }
        guard palette.contains(where: { $0.role == "player" }),
              palette.contains(where: { $0.role == "hunted" })
        else {
            throw VisualLanguageError.palette
        }
        guard let boxes = root["spriteBoxes"] as? [String: Any],
              let player = dimension(boxes["playerAndStandardEnemy"], 64, 64),
              let daemon = dimension(boxes["improperSearchDaemon"], 80, 80),
              let boss = dimension(boxes["algorithmicModerate"], 96, 96),
              let pole = dimension(boxes["cameraPole"], 64, 96),
              let envMultiple = intValue(boxes["environmentModuleMultiple"]), envMultiple == 64
        else {
            throw VisualLanguageError.boxes
        }
        guard let atlases = root["atlases"] as? [String], atlases.count == 8,
              let pattern = root["deliveryNamePattern"] as? String, !pattern.isEmpty,
              root["colorIsNotSoleCarrier"] as? Bool == true,
              root["collisionNeverFromSpriteBounds"] as? Bool == true,
              root["groundContactMustBeStable"] as? Bool == true,
              root["filtering"] as? String == "nearestNeighbor"
        else {
            throw VisualLanguageError.invalidJSON
        }
        return VisualLanguage(
            schemaVersion: "visual-language-001",
            visualVersion: "visual-civic-seam-001",
            authoringGridUnits: grid,
            actorFootprintUnits: VisualRange(min: fpMin, max: fpMax),
            filtering: "nearestNeighbor",
            salience: salience,
            palette: palette,
            spriteBoxes: [
                "playerAndStandardEnemy": player,
                "improperSearchDaemon": daemon,
                "algorithmicModerate": boss,
                "cameraPole": pole
            ],
            environmentModuleMultiple: envMultiple,
            atlases: atlases,
            deliveryNamePattern: pattern,
            colorIsNotSoleCarrier: true,
            collisionNeverFromSpriteBounds: true,
            groundContactMustBeStable: true
        )
    }

    private static func dimension(_ value: Any?, _ width: Int, _ height: Int) -> AssetDimensions? {
        guard let object = value as? [String: Any],
              let w = intValue(object["width"]), w == width,
              let h = intValue(object["height"]), h == height
        else {
            return nil
        }
        return AssetDimensions(width: w, height: h)
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }
}
