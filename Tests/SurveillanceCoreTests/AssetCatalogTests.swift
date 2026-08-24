import Foundation
import Testing
@testable import SurveillanceCore

@Test func bundledAssetCatalogFailsClosedAndCoversPresentationIDs() throws {
    let catalog = try AssetCatalog.bundled()
    #expect(catalog.legacyCommit == LegacyEvidence.commit)
    #expect(catalog.specificationCommit == ContractVersions.specificationCommit)
    #expect(catalog.entries.contains { $0.record.productionStatus == .accepted } == false)

    let presentation = try JSONSerialization.jsonObject(
        with: SpecBundle.contract("presentation-assets-001")
    ) as! [String: Any]
    let required = (presentation["requiredAssetIds"] as! [String]) + (presentation["audioEventIds"] as! [String])
    #expect(required.count == 51)
    for id in required {
        let entry = try #require(catalog.entries.first { $0.record.assetId == id })
        #expect(entry.admissionDecision == .plannedOriginal)
        #expect(entry.record.runtimeRequired)
        #expect(entry.record.productionStatus == .planned)
        #expect(entry.record.provenance == .projectOriginal)
        #expect(entry.record.source == nil)
        #expect(entry.record.runtimePath == nil)
        #expect(entry.record.sha256 == nil)
    }

    let sfVisual = catalog.entries.filter {
        $0.record.assetId.hasPrefix("legacy_san_francisco_") && $0.record.kind == .sprite
    }
    #expect(sfVisual.count == 13)
    let bridge = try #require(
        sfVisual.first { $0.record.assetId == "legacy_san_francisco_landmark_bridge_distant_01" }
    )
    #expect(bridge.admissionDecision == .rejected)
    #expect(sfVisual.filter { $0.admissionDecision == .sfCandidate }.count == 12)

    let atlanta = try #require(
        catalog.entries.first { $0.record.assetId == "legacy_atlanta_decal_beltline_stripe_01" }
    )
    #expect(atlanta.admissionDecision == .excluded)
    #expect(atlanta.record.runtimeRequired == false)

    let fog = try #require(
        catalog.entries.first { $0.record.assetId == "legacy_sfx_san_francisco_hidden_sensor_fog" }
    )
    #expect(fog.admissionDecision == .rejected)
    #expect(fog.record.sha256 == "d6e925e768222ebfcf5c0bd12cd3faef493f134105bb0a8f07003f842ece06e4")
}

@Test func excludedOrAcceptedWithoutHashCatalogsFailClosed() throws {
    let good = try JSONSerialization.jsonObject(
        with: SpecBundle.contract("asset-catalog-001")
    ) as! [String: Any]
    let presentation = SpecBundle.contract("presentation-assets-001")

    func encode(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object)
    }

    var badSchema = good
    badSchema["schemaVersion"] = "asset-catalog-000"
    do {
        _ = try AssetCatalogLoader.decodeAndValidate(
            catalogJSON: encode(badSchema),
            presentationJSON: presentation
        )
        Issue.record("expected schema failure")
        return
    } catch AssetCatalogError.schemaVersion {
    }

    var accepted = good
    var entries = accepted["entries"] as! [[String: Any]]
    var record = entries[0]["record"] as! [String: Any]
    record["productionStatus"] = "accepted"
    record["runtimeRequired"] = false
    record["sha256"] = NSNull()
    record["license"] = "x"
    record["source"] = "x"
    record["runtimePath"] = "RuntimeAssets/x.png"
    entries[0]["record"] = record
    accepted["entries"] = entries
    do {
        _ = try AssetCatalogLoader.decodeAndValidate(
            catalogJSON: encode(accepted),
            presentationJSON: presentation
        )
        Issue.record("expected accepted-without-hash failure")
        return
    } catch AssetCatalogError.acceptedWithoutProvenance("legacy_atlanta_decal_beltline_stripe_01") {
    }

    var excludedRequired = good
    var excludedEntries = excludedRequired["entries"] as! [[String: Any]]
    var excludedRecord = excludedEntries[0]["record"] as! [String: Any]
    excludedRecord["runtimeRequired"] = true
    excludedEntries[0]["record"] = excludedRecord
    excludedRequired["entries"] = excludedEntries
    do {
        _ = try AssetCatalogLoader.decodeAndValidate(
            catalogJSON: encode(excludedRequired),
            presentationJSON: presentation
        )
        Issue.record("expected excluded runtimeRequired failure")
        return
    } catch AssetCatalogError.excludedRuntimeRequired("legacy_atlanta_decal_beltline_stripe_01") {
    }
}

@Test func pulledSanFranciscoEvidenceHashesMatchCatalog() throws {
    let catalog = try AssetCatalog.bundled()
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    let groove = try #require(catalog.recordsByID["legacy_san_francisco_decal_cable_groove_01"])
    let grooveURL = root.appendingPathComponent(groove.source!)
    let grooveData = try Data(contentsOf: grooveURL)
    #expect(SHA256.hex(Array(grooveData)) == groove.sha256)
    #expect(groove.dimensions == AssetDimensions(width: 256, height: 256))

    let fog = try #require(catalog.recordsByID["legacy_sfx_san_francisco_hidden_sensor_fog"])
    let fogData = try Data(contentsOf: root.appendingPathComponent(fog.source!))
    #expect(SHA256.hex(Array(fogData)) == fog.sha256)
    #expect([UInt8](fogData.prefix(4)) == Array("caff".utf8))
}
