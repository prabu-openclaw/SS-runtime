import Testing
@testable import SurveillanceCore

@Suite(.serialized)
struct RuntimeBundleTests {
    @Test func runtimeBundleT805ProjectsOnlyReachablePlannedOriginals() throws {
        let catalog = try AssetCatalog.bundled()
        let reachable = try RuntimeBundleFilter.reachableAssetIds()
        let projection = RuntimeBundleFilter.project(catalog: catalog, reachable: reachable)
        #expect(projection.bundleAssetIds.count == 52)
        #expect(projection.excludedAssetIds.count == catalog.entries.count - 52)
        #expect(projection.bundleAssetIds.allSatisfy { reachable.contains($0) })
        #expect(
            catalog.entries.filter { $0.admissionDecision == .plannedOriginal }.map(\.record.assetId).sorted()
                == projection.bundleAssetIds
        )
        #expect(
            catalog.entries.filter { $0.admissionDecision != .plannedOriginal }.allSatisfy {
                !projection.bundleAssetIds.contains($0.record.assetId)
            }
        )
    }

    @Test func runtimeBundleT805BundledCatalogHasNoBundleViolations() throws {
        let catalog = try AssetCatalog.bundled()
        let reachable = try RuntimeBundleFilter.reachableAssetIds()
        let issues = RuntimeBundleFilter.validate(catalog: catalog, reachable: reachable)
        #expect(issues.isEmpty)
    }

    @Test func runtimeBundleT805RejectsLegacyEvidenceWithRuntimePath() throws {
        let catalog = try AssetCatalog.bundled()
        let reachable = try RuntimeBundleFilter.reachableAssetIds()
        var record = try #require(catalog.recordsByID["legacy_san_francisco_decal_cable_groove_01"])
        record.runtimePath = "RuntimeAssets/legacy_san_francisco_decal_cable_groove_01.png"
        record.runtimeRequired = true
        let entry = AssetCatalogEntry(admissionDecision: .sfCandidate, record: record)
        var entries = catalog.entries.filter { $0.record.assetId != record.assetId }
        entries.append(entry)
        let mutated = AssetCatalog(
            schemaVersion: catalog.schemaVersion,
            legacyRepository: catalog.legacyRepository,
            legacyCommit: catalog.legacyCommit,
            specificationCommit: catalog.specificationCommit,
            entries: entries
        )
        let issues = RuntimeBundleFilter.validate(catalog: mutated, reachable: reachable)
        #expect(issues.contains(.legacyEvidenceInBundle(record.assetId)))
        #expect(issues.contains(.nonSanFranciscoInBundle(record.assetId)) == false)
    }

    @Test func runtimeBundleT807CatalogContentAuditPassesForBundledCatalog() throws {
        let catalog = try AssetCatalog.bundled()
        #expect(try CivicSeamIdentity.catalogPassesContentAudit(catalog))
        #expect(try CivicSeamIdentity.catalogContentAudit(catalog).isEmpty)
    }
}
