import Testing
@testable import SurveillanceCore

@Suite(.serialized)
struct CivicSeamIdentityTests {
    @Test func civicSeamT307SpineGridsWedgesAndLandmarks() throws {
        let arena = try ArenaManifest.bundled()
        #expect(CivicSeamIdentity.zoneNamesMatchContract(arena))
        #expect(CivicSeamIdentity.diagonalSpine(arena))
        #expect(CivicSeamIdentity.threeGridCollision(arena))
        #expect(CivicSeamIdentity.wedgeParcels(arena))
        #expect(CivicSeamIdentity.landmarkSightlines(arena))
    }

    @Test func civicSeamT308IdentityOmitsLiteralMapLabels() throws {
        let catalog = try AssetCatalog.bundled()
        #expect(CivicSeamIdentity.presentationOmitsProhibitedLabels())
        #expect(CivicSeamIdentity.catalogRejectsLiteralLandmarks(catalog))
        #expect(catalog.entries.allSatisfy { $0.record.runtimePath == nil })
    }
}
