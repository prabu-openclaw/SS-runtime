import Foundation

/// T801: runtime-facing asset registry limited to reachable SS-001 bundle IDs.
public struct PresentationAssetRegistry: Equatable, Sendable {
    public var bundleAssetIds: [String]
    public var requiredVisualAssetIds: [String]
    public var audioEventIds: [String]

    public init(
        bundleAssetIds: [String],
        requiredVisualAssetIds: [String],
        audioEventIds: [String]
    ) {
        self.bundleAssetIds = bundleAssetIds
        self.requiredVisualAssetIds = requiredVisualAssetIds
        self.audioEventIds = audioEventIds
    }

    public static func bundled() throws -> PresentationAssetRegistry {
        let catalog = try AssetCatalog.bundled()
        let reachable = try RuntimeBundleFilter.reachableAssetIds()
        let projection = RuntimeBundleFilter.project(catalog: catalog, reachable: reachable)
        guard let presentation = try? JSONSerialization.jsonObject(
            with: SpecBundle.contract("presentation-assets-001")
        ) as? [String: Any],
            let visuals = presentation["requiredAssetIds"] as? [String],
            let audio = presentation["audioEventIds"] as? [String]
        else {
            throw AssetCatalogError.invalidJSON
        }
        return PresentationAssetRegistry(
            bundleAssetIds: projection.bundleAssetIds,
            requiredVisualAssetIds: visuals,
            audioEventIds: audio
        )
    }

    public func contains(_ assetId: String) -> Bool {
        bundleAssetIds.contains(assetId)
    }

    public func require(_ assetId: String) throws -> String {
        guard contains(assetId) else {
            throw PresentationAssetRegistryError.unreachable(assetId)
        }
        return assetId
    }
}

public enum PresentationAssetRegistryError: Equatable, Sendable, Error {
    case unreachable(String)
}
